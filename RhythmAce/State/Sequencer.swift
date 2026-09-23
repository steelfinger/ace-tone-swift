import Foundation
import Observation

/// UI-facing state. Every change is pushed straight into the engine's
/// SharedControl; the render thread picks it up on the next buffer.
@MainActor
@Observable
final class Sequencer {
    @ObservationIgnored let engine = AudioEngine()
    var control: SharedControl { engine.control }

    private(set) var selected: [String] = ["rock"] { didSet { pushPattern() } }

    static let bpmRange = 40.0...240.0

    var bpm: Double = 110 {
        didSet { control.bpm = bpm }
    }

    var volume: Double = 0.8 {
        didSet { control.volume = volume }
    }

    private(set) var mutes: Set<VoiceID> = []

    /// True only while the audio engine is actually running the pattern.
    private(set) var running = false {
        didSet { control.running.store(running, ordering: .relaxed) }
    }

    /// Set when the engine couldn't start or died; cleared by the next START.
    private(set) var audioError: String?

    init() {
        control.bpm = bpm
        control.volume = volume
        pushPattern()
        engine.onStatus = { [weak self] status in
            guard let self else { return }
            switch status {
            case .running:
                audioError = nil
                running = true
            case .stopped:
                running = false
            case .failed(let message):
                running = false
                audioError = message
            }
        }
    }

    func toggleRunning() {
        if running {
            stop()
        } else {
            start()
        }
    }

    /// START only lights up once the engine has really started.
    func start() {
        do {
            try engine.start()
            audioError = nil
            running = true
        } catch {
            running = false
            audioError = error.localizedDescription
        }
    }

    func stop() {
        running = false
        engine.stop()
    }

    func dismissAudioError() { audioError = nil }

    var combined: CombinedPattern { .combine(selected) }

    func toggleSelected(_ pat: Pattern) {
        if selected.contains(pat.id) {
            selected.removeAll { $0 == pat.id }
            return
        }
        // Enforce same time signature among selected: Waltz only combines with Waltz
        let existing = combined
        if existing.steps != 0 && existing.steps != pat.steps {
            selected = [pat.id]
        } else {
            selected.append(pat.id)
        }
    }

    func setBpm(_ v: Double) { bpm = min(Self.bpmRange.upperBound, max(Self.bpmRange.lowerBound, v.rounded())) }

    func setVolume(_ v: Double) { volume = min(1, max(0, v)) }

    func toggleMute(_ v: VoiceID) {
        if mutes.contains(v) { mutes.remove(v) } else { mutes.insert(v) }
        let mask = mutes.reduce(UInt8(0)) { $0 | (1 << UInt8($1.rawValue)) }
        control.muteMask.store(mask, ordering: .relaxed)
    }

    private func pushPattern() {
        control.setPattern(combined)
    }
}
