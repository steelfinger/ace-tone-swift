import Foundation

enum VoiceID: Int, CaseIterable, Sendable {
    case bd, sd, lc, hc, cy, cl, cb, mc
}

enum Wave: Sendable { case sine, triangle, square, noise }

enum FilterSpec: Sendable {
    case none
    case highpass(freq: Double)
    case bandpass(freq: Double, q: Double)
}

/// One sound layer of a voice: a source, an optional biquad, and an AR envelope.
/// Mirrors the Web Audio graphs from the RN version one-to-one.
struct LayerSpec: Sendable {
    var voice: VoiceID
    var wave: Wave
    var freq: Double = 0          // start frequency
    var freqEnd: Double? = nil    // exponential sweep target
    var sweep: Double = 0         // sweep time (s)
    var freq2: Double? = nil      // second oscillator, same wave (cowbell)
    var filter: FilterSpec = .none
    var peak: Double              // envelope peak gain
    var decay: Double             // time (s) to reach -80 dB
    var length: Double            // time (s) the source runs (osc.stop)
}

let LAYERS: [LayerSpec] = [
    // BASS DRUM — LC oscillator ~60 Hz with fast pitch sweep, ~200 ms decay
    LayerSpec(voice: .bd, wave: .sine, freq: 130, freqEnd: 48, sweep: 0.06,
              peak: 0.9, decay: 0.22, length: 0.3),
    // SNARE — tonal body (~180 Hz triangle) + filtered noise burst
    LayerSpec(voice: .sd, wave: .triangle, freq: 220, freqEnd: 170, sweep: 0.05,
              peak: 0.35, decay: 0.12, length: 0.15),
    LayerSpec(voice: .sd, wave: .noise, filter: .highpass(freq: 1200),
              peak: 0.5, decay: 0.18, length: 0.2),
    // LOW CONGA — resonant sine w/ short pitch drop, woody decay
    LayerSpec(voice: .lc, wave: .sine, freq: 180, freqEnd: 120, sweep: 0.08,
              peak: 0.7, decay: 0.25, length: 0.3),
    // HIGH CONGA — same topology, higher pitch
    LayerSpec(voice: .hc, wave: .sine, freq: 320, freqEnd: 230, sweep: 0.06,
              peak: 0.65, decay: 0.18, length: 0.25),
    // CYMBAL — HPF white noise, long decay (~400 ms)
    LayerSpec(voice: .cy, wave: .noise, filter: .highpass(freq: 7000),
              peak: 0.35, decay: 0.35, length: 0.45),
    // CLAVES — pure sine ~2.5 kHz, very short (~40 ms)
    LayerSpec(voice: .cl, wave: .sine, freq: 2500,
              peak: 0.55, decay: 0.05, length: 0.06),
    // COWBELL — two squares (540/800 Hz) through BPF, ~300 ms decay
    LayerSpec(voice: .cb, wave: .square, freq: 540, freq2: 800,
              filter: .bandpass(freq: 650, q: 4),
              peak: 0.18, decay: 0.3, length: 0.35),
    // MARACAS — BPF noise, very short attack/decay
    LayerSpec(voice: .mc, wave: .noise, filter: .bandpass(freq: 6000, q: 1.5),
              peak: 0.3, decay: 0.06, length: 0.08),
]

/// RBJ-cookbook biquad, matching Web Audio's BiquadFilterNode.
struct Biquad {
    var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    init(_ spec: FilterSpec, sampleRate sr: Double) {
        let w0: Double, alpha: Double, cosw: Double, a0: Double
        switch spec {
        case .none:
            return
        case .highpass(let f):
            // Web Audio default Q = 1 dB for HP/LP → linear 10^(1/20)
            w0 = 2 * .pi * f / sr; cosw = cos(w0)
            alpha = sin(w0) / (2 * pow(10, 1.0 / 20))
            a0 = 1 + alpha
            b0 = (1 + cosw) / 2 / a0; b1 = -(1 + cosw) / a0; b2 = b0
        case .bandpass(let f, let q):
            // constant 0 dB peak gain
            w0 = 2 * .pi * f / sr; cosw = cos(w0)
            alpha = sin(w0) / (2 * q)
            a0 = 1 + alpha
            b0 = alpha / a0; b1 = 0; b2 = -alpha / a0
        }
        a1 = -2 * cosw / a0
        a2 = (1 - alpha) / a0
    }

    mutating func reset() { x1 = 0; x2 = 0; y1 = 0; y2 = 0 }

    @inline(__always)
    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x; y2 = y1; y1 = y
        return y
    }
}

/// A playing instance of a LayerSpec. All coefficients are precomputed so
/// `next()` does only arithmetic — safe on the real-time audio thread.
struct LayerVoice {
    let voice: Int
    let wave: Wave
    let hasFilter: Bool
    let inc1: Double, inc2: Double           // phase increments (cycles/sample)
    let sweepMul: Double, sweepSamples: Int  // per-sample freq multiplier
    let attackSamples: Int, decaySamples: Int, lengthSamples: Int
    let attackMul: Double, decayMul: Double
    let peak: Double
    var filter: Biquad

    var active = false
    var n = 0                 // samples since trigger
    var phase1 = 0.0, phase2 = 0.0
    var freqScale = 1.0
    var env = 0.0

    static let floor = 0.0001
    static let attack = 0.002

    init(_ s: LayerSpec, sampleRate sr: Double) {
        voice = s.voice.rawValue
        wave = s.wave
        inc1 = s.freq / sr
        inc2 = (s.freq2 ?? 0) / sr
        sweepSamples = Int(s.sweep * sr)
        if let end = s.freqEnd, sweepSamples > 0 {
            sweepMul = pow(end / s.freq, 1 / Double(sweepSamples))
        } else {
            sweepMul = 1
        }
        attackSamples = max(1, Int(Self.attack * sr))
        decaySamples = max(attackSamples + 1, Int(s.decay * sr))
        lengthSamples = Int(s.length * sr)
        peak = s.peak
        attackMul = pow(s.peak / Self.floor, 1 / Double(attackSamples))
        decayMul = pow(Self.floor / s.peak, 1 / Double(decaySamples - attackSamples))
        if case .none = s.filter { hasFilter = false } else { hasFilter = true }
        filter = Biquad(s.filter, sampleRate: sr)
    }

    mutating func trigger() {
        active = true
        n = 0
        phase1 = 0; phase2 = 0
        freqScale = 1
        env = Self.floor
        filter.reset()
    }

    /// Next output sample. `noise` is the shared noise table; like the
    /// Web Audio version, every hit plays it from the start.
    @inline(__always)
    mutating func next(noise: UnsafeMutableBufferPointer<Float>) -> Double {
        if n >= lengthSamples { active = false; return 0 }

        var x: Double
        switch wave {
        case .sine:
            x = sin(2 * .pi * phase1)
        case .triangle:
            x = phase1 < 0.25 ? 4 * phase1 : (phase1 < 0.75 ? 2 - 4 * phase1 : 4 * phase1 - 4)
        case .square:
            x = Self.square(phase1, inc1 * freqScale)
            if inc2 > 0 { x += Self.square(phase2, inc2 * freqScale) }
        case .noise:
            x = Double(noise[n % noise.count])
        }
        if hasFilter { x = filter.process(x) }
        let out = x * env

        // advance oscillators
        phase1 += inc1 * freqScale; if phase1 >= 1 { phase1 -= 1 }
        if inc2 > 0 { phase2 += inc2 * freqScale; if phase2 >= 1 { phase2 -= 1 } }
        if n < sweepSamples { freqScale *= sweepMul }

        // advance envelope: exp ramp floor→peak, then exp ramp peak→floor, then hold
        if n < attackSamples { env *= attackMul }
        else if n < decaySamples { env *= decayMul }
        else { env = Self.floor }

        n += 1
        return out
    }

    /// Band-limited square via PolyBLEP (Web Audio oscillators are band-limited).
    @inline(__always)
    static func square(_ p: Double, _ dt: Double) -> Double {
        var v = p < 0.5 ? 1.0 : -1.0
        v += polyBLEP(p, dt)
        var p2 = p + 0.5; if p2 >= 1 { p2 -= 1 }
        v -= polyBLEP(p2, dt)
        return v
    }

    @inline(__always)
    static func polyBLEP(_ t: Double, _ dt: Double) -> Double {
        if t < dt { let x = t / dt; return x + x - x * x - 1 }
        if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
        return 0
    }
}
