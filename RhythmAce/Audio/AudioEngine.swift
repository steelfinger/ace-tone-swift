import AVFAudio

/// Owns the AVAudioEngine graph: one AVAudioSourceNode whose render block
/// runs SynthCore. Rebuilt when the hardware format changes (route change,
/// interruption), since SynthCore bakes the sample rate into its coefficients.
@MainActor
final class AudioEngine {
    let control = SharedControl()

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var observers: [NSObjectProtocol] = []

    init() {
        configureSession()
        build()

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        })
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.ended.rawValue else { return }
            MainActor.assumeIsolated { self?.rebuild() }
        })
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }
    }

    private func build() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate > 0 ? sampleRate : 48_000,
                                   channels: 1)!
        let core = SynthCore(sampleRate: format.sampleRate, control: control)
        let node = AVAudioSourceNode(format: format, renderBlock: Self.makeRenderBlock(core))
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        source = node
        do {
            try engine.start()
        } catch {
            print("AVAudioEngine start failed: \(error)")
        }
    }

    private func rebuild() {
        engine.stop()
        if let source {
            engine.detach(source)
        }
        source = nil
        try? AVAudioSession.sharedInstance().setActive(true)
        build()
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
