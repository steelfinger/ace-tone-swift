import Synchronization

/// Lock-free parameter exchange between the UI (writer) and the render
/// thread (reader), plus the lamp state going the other way.
final class SharedControl: Sendable {
    private let bpmBits = Atomic<UInt64>(Double(110).bitPattern)
    private let volumeBits = Atomic<UInt64>(Double(0.8).bitPattern)
    let running = Atomic<Bool>(false)
    let muteMask = Atomic<UInt8>(0)

    // Combined pattern: 8 voices × 16 steps packed into two words.
    // A torn read between the two words can only mix two patterns for a
    // single step, which is inaudible in practice.
    let gridLo = Atomic<UInt64>(0)
    let gridHi = Atomic<UInt64>(0)
    let steps = Atomic<Int>(0)

    /// Written by the render thread: quarter-note pulse for the power lamp.
    let lampLit = Atomic<Bool>(false)

    var bpm: Double {
        get { Double(bitPattern: bpmBits.load(ordering: .relaxed)) }
        set { bpmBits.store(newValue.bitPattern, ordering: .relaxed) }
    }

    var volume: Double {
        get { Double(bitPattern: volumeBits.load(ordering: .relaxed)) }
        set { volumeBits.store(newValue.bitPattern, ordering: .relaxed) }
    }

    func setPattern(_ p: CombinedPattern) {
        let (lo, hi) = p.packed
        gridLo.store(lo, ordering: .relaxed)
        gridHi.store(hi, ordering: .relaxed)
        steps.store(p.steps, ordering: .releasing)
    }
}
