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

    var bpm: Double = 110 {
        didSet { control.bpm = bpm }
    }

    var volume: Double = 0.8 {
        didSet { control.volume = volume }
    }

    private(set) var mutes: Set<VoiceID> = []

    var running = false {
        didSet { control.running.store(running, ordering: .relaxed) }
    }

    init() {
        control.bpm = bpm
        control.volume = volume
        pushPattern()
    }

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

    func setBpm(_ v: Double) { bpm = v.rounded() }

    func toggleMute(_ v: VoiceID) {
        if mutes.contains(v) { mutes.remove(v) } else { mutes.insert(v) }
        let mask = mutes.reduce(UInt8(0)) { $0 | (1 << UInt8($1.rawValue)) }
        control.muteMask.store(mask, ordering: .relaxed)
    }

    private func pushPattern() {
        control.setPattern(combined)
    }
}
