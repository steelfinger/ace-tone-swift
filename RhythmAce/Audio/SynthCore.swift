import AVFAudio

/// The real-time part: sequencer clock + voice mixing, run entirely inside
/// the audio render callback. Steps are triggered on the exact sample they
/// fall on, so there's no lookahead scheduler and no timer jitter.
///
/// Everything here is touched only by the render thread (after init), except
/// `control`, which is atomics. No allocations, locks or ObjC calls in `render`.
final class SynthCore: @unchecked Sendable {
    let sampleRate: Double
    let control: SharedControl

    /// Instances per layer. Overlapping hits ring out like the Web Audio
    /// version (which created fresh nodes per hit); the oldest is stolen.
    private static let polyphony = 8

    private let pool: UnsafeMutableBufferPointer<LayerVoice>
    private let noise: UnsafeMutableBufferPointer<Float>
    private let layerCount: Int
    private var nextSlot: [Int]            // round-robin slot per layer (preallocated)
    private let layersForVoice: [[Int]]    // voice → layer indices (read-only)

    // Sequencer state
    private var wasRunning = false
    private var step = 0
    private var samplesToNextStep = 0.0
    private var lampSamples = 0
    private var gain: Double

    private static let flashSeconds = 0.08

    init(sampleRate: Double, control: SharedControl) {
        self.sampleRate = sampleRate
        self.control = control

        layerCount = LAYERS.count
        pool = .allocate(capacity: layerCount * Self.polyphony)
        for (i, spec) in LAYERS.enumerated() {
            for k in 0..<Self.polyphony {
                (pool.baseAddress! + i * Self.polyphony + k)
                    .initialize(to: LayerVoice(spec, sampleRate: sampleRate))
            }
        }
        nextSlot = Array(repeating: 0, count: layerCount)
        layersForVoice = VoiceID.allCases.map { v in
            LAYERS.indices.filter { LAYERS[$0].voice == v }
        }

        // 2 s of white noise, generated once (same as the RN version)
        noise = .allocate(capacity: Int(sampleRate * 2))
        var rng = SystemRandomNumberGenerator()
        for i in 0..<noise.count { noise[i] = Float.random(in: -1...1, using: &rng) }

        gain = control.volume
    }

    deinit {
        pool.deinitialize()
        pool.deallocate()
        noise.deallocate()
    }

    private func trigger(voice: Int) {
        for layer in layersForVoice[voice] {
            let slot = nextSlot[layer]
            nextSlot[layer] = (slot + 1) % Self.polyphony
            pool[layer * Self.polyphony + slot].trigger()
        }
    }

    private func playStep(lo: UInt64, hi: UInt64, steps: Int) {
        let s = step % steps
        for v in 0..<8 {
            let word = v < 4 ? lo : hi
            let row = UInt16(truncatingIfNeeded: word >> (16 * UInt64(v % 4)))
            if row & (1 << s) != 0 { trigger(voice: v) }
        }
        // Pulse on every quarter-note: 16-step = 16ths (÷4), 12-step waltz = 8ths (÷2)
        let stepDiv = steps == 12 ? 2 : 4
        if s % stepDiv == 0 { lampSamples = Int(Self.flashSeconds * sampleRate) }
        step = s + 1
    }

    func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        let running = control.running.load(ordering: .relaxed)
        let steps = control.steps.load(ordering: .acquiring)
        let lo = control.gridLo.load(ordering: .relaxed)
        let hi = control.gridHi.load(ordering: .relaxed)
        let mutes = control.muteMask.load(ordering: .relaxed)
        let bpm = control.bpm
        let targetGain = control.volume

        if running && !wasRunning {
            step = 0
            samplesToNextStep = 0
        }
        if !running { lampSamples = 0 }
        wasRunning = running

        let stepDiv = steps == 12 ? 2.0 : 4.0
        let samplesPerStep = sampleRate * 60 / bpm / stepDiv
        // ~5 ms one-pole smoothing so the volume knob doesn't zipper
        let smooth = 1 - exp(-1 / (0.005 * sampleRate))

        for i in 0..<frames {
            if running {
                if samplesToNextStep <= 0 {
                    if steps > 0 { playStep(lo: lo, hi: hi, steps: steps) }
                    samplesToNextStep += samplesPerStep
                }
                samplesToNextStep -= 1
            }

            var mix = 0.0
            for j in 0..<pool.count where pool[j].active {
                let s = pool[j].next(noise: noise)
                // Cancel buttons hard-mute the voice bus, tails included
                if mutes & (1 << UInt8(pool[j].voice)) == 0 { mix += s }
            }

            gain += (targetGain - gain) * smooth
            out[i] = Float(max(-1, min(1, mix * gain)))

            if lampSamples > 0 { lampSamples -= 1 }
        }

        let lit = lampSamples > 0
        if control.lampLit.load(ordering: .relaxed) != lit {
            control.lampLit.store(lit, ordering: .relaxed)
        }
    }
}
