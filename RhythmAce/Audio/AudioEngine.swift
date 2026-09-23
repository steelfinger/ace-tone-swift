import AVFAudio

/// Owns the AVAudioEngine graph: one AVAudioSourceNode whose render block
/// runs SynthCore. Nothing touches the audio session until `start()` — the
/// user's music keeps playing until they press START — and `stop()` gives
/// the session back with `.notifyOthersOnDeactivation`.
///
/// The graph is rebuilt on every start and on route/config changes, since
/// SynthCore bakes the hardware sample rate into its coefficients.
@MainActor
final class AudioEngine {
    enum Status: Equatable {
        case running
        case stopped
        case failed(String)
    }

    let control = SharedControl()

    /// Called when playback starts or stops for a reason other than the
    /// caller asking (interruption, route loss, engine failure, resume).
    var onStatus: ((Status) -> Void)?

    private var engine: AVAudioEngine?
    private var observers: [NSObjectProtocol] = []
    private var pendingTeardown: Task<Void, Never>?
    private var resumeAfterInterruption = false

    /// Longest voice tail is the cymbal at 0.45 s; let it ring out on STOP.
    private static let tailSeconds = 0.6

    var isRunning: Bool { engine?.isRunning ?? false }

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
        ) { [weak self] note in
            let source = note.object as? AVAudioEngine
            MainActor.assumeIsolated { self?.configurationChanged(source) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(
                rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated { self?.interruption(type, options) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            MainActor.assumeIsolated { self?.routeChanged(reason) }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.mediaServicesReset() }
        })
    }

    // MARK: Start / stop

    func start() throws {
        pendingTeardown?.cancel()
        pendingTeardown = nil
        resumeAfterInterruption = false
        try activate()
    }

    /// Lets the current tails ring out, then stops the engine and releases
    /// the session. The caller has already cleared `control.running`.
    func stop() {
        resumeAfterInterruption = false
        pendingTeardown?.cancel()
        pendingTeardown = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.tailSeconds))
            guard !Task.isCancelled else { return }
            self?.teardown(deactivateSession: true)
        }
    }

    private func activate() throws {
        teardown(deactivateSession: false)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate > 0 ? sampleRate : 48_000,
                                   channels: 1)!
        let core = SynthCore(sampleRate: format.sampleRate, control: control)
        let node = AVAudioSourceNode(format: format, renderBlock: Self.makeRenderBlock(core))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        self.engine = engine
        do {
            try engine.start()
        } catch {
            teardown(deactivateSession: true)
            throw error
        }
    }

    private func teardown(deactivateSession: Bool) {
        engine?.stop()
        engine = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance()
                .setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    /// Stops everything because the system took the output away.
    private func halt(_ status: Status, deactivateSession: Bool) {
        pendingTeardown?.cancel()
        pendingTeardown = nil
        control.running.store(false, ordering: .relaxed)
        teardown(deactivateSession: deactivateSession)
        onStatus?(status)
    }

    // MARK: System events

    private func configurationChanged(_ source: AVAudioEngine?) {
        // Only the live engine; ignore stragglers from ones we already dropped.
        guard let source, source === engine else { return }
        do {
            try activate()
        } catch {
            halt(.failed(error.localizedDescription), deactivateSession: true)
        }
    }

    private func interruption(_ type: AVAudioSession.InterruptionType?,
                              _ options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            // Only a live START is worth resuming — not one already stopping.
            resumeAfterInterruption = control.running.load(ordering: .relaxed)
            // The system has already deactivated the session.
            halt(.stopped, deactivateSession: false)
        case .ended:
            defer { resumeAfterInterruption = false }
            guard resumeAfterInterruption, options.contains(.shouldResume) else { return }
            do {
                try activate()
                control.running.store(true, ordering: .relaxed)
                onStatus?(.running)
            } catch {
                halt(.failed(error.localizedDescription), deactivateSession: true)
            }
        default:
            break
        }
    }

    /// Unplugging headphones (or losing Bluetooth) pauses instead of blasting
    /// the speaker, per Apple's playback guidance.
    private func routeChanged(_ reason: AVAudioSession.RouteChangeReason?) {
        guard reason == .oldDeviceUnavailable, control.running.load(ordering: .relaxed) else { return }
        halt(.stopped, deactivateSession: true)
    }

    /// The audio daemon restarted: every AVAudio object is invalid. Rebuild
    /// from scratch if we were playing, otherwise there's nothing to restore.
    private func mediaServicesReset() {
        let wasRunning = control.running.load(ordering: .relaxed)
        engine = nil
        guard wasRunning else { return }
        do {
            try activate()
        } catch {
            halt(.failed(error.localizedDescription), deactivateSession: true)
        }
    }

    /// Built in a nonisolated context so the closure isn't inferred as
    /// MainActor-isolated — it's called on the real-time audio thread.
    private nonisolated static func makeRenderBlock(_ core: SynthCore) -> AVAudioSourceNodeRenderBlock {
        return { _, _, frameCount, bufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard let data = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            core.render(frames: Int(frameCount), into: data)
            return noErr
        }
    }
}
