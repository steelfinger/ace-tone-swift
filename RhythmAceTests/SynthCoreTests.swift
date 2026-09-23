import Testing
@testable import RhythmAce

/// Drives SynthCore offline, one frame at a time, the way the render
/// callback would.
struct SynthCoreTests {
    static let sampleRate = 48_000.0

    private func makeCore(pattern ids: [String], bpm: Double = 120,
                          mutes: UInt8 = 0) -> (SynthCore, SharedControl) {
        let control = SharedControl()
        control.bpm = bpm
        control.volume = 1
        control.setPattern(.combine(ids))
        control.muteMask.store(mutes, ordering: .relaxed)
        control.running.store(true, ordering: .relaxed)
        return (SynthCore(sampleRate: Self.sampleRate, control: control), control)
    }

    /// Renders `frames` samples one at a time, returning the output.
    private func render(_ core: SynthCore, frames: Int) -> [Float] {
        var out = [Float](repeating: 0, count: frames)
        var one: Float = 0
        for i in 0..<frames {
            core.render(frames: 1, into: &one)
            out[i] = one
        }
        return out
    }

    /// Sample indices where sound starts after at least `gap` samples of silence.
    private func onsets(_ samples: [Float], gap: Int = 2_000) -> [Int] {
        var result: [Int] = []
        var lastLoud = -gap - 1
        for (i, s) in samples.enumerated() where abs(s) > 1e-3 {
            if i - lastLoud > gap { result.append(i) }
            lastLoud = i
        }
        return result
    }

    /// Rising edges of the power lamp (quarter-note pulses).
    private func lampEdges(_ core: SynthCore, _ control: SharedControl, frames: Int) -> [Int] {
        var edges: [Int] = []
        var was = false
        var one: Float = 0
        for i in 0..<frames {
            core.render(frames: 1, into: &one)
            let lit = control.lampLit.load(ordering: .relaxed)
            if lit && !was { edges.append(i) }
            was = lit
        }
        return edges
    }

    @Test func sixteenStepBarLastsFourBeats() {
        let (core, control) = makeCore(pattern: ["rock"])
        let edges = lampEdges(core, control, frames: 100_000)
        // 120 bpm → quarter note every 24 000 samples
        #expect(edges.count == 5)
        for (a, b) in zip(edges, edges.dropFirst()) { #expect(abs(b - a - 24_000) <= 1) }
    }

    @Test func waltzKeepsTheSameQuarterNoteAtTwelveSteps() {
        let (core, control) = makeCore(pattern: ["waltz"])
        let edges = lampEdges(core, control, frames: 100_000)
        #expect(edges.count == 5)
        for (a, b) in zip(edges, edges.dropFirst()) { #expect(abs(b - a - 24_000) <= 1) }
    }

    @Test func waltzBassDrumRepeatsEveryTwelveStepsAndDixielandEveryFour() {
        // Bass drum only, isolated via mutes of everything else.
        let allButBass: UInt8 = 0xFF & ~(1 << UInt8(VoiceID.bd.rawValue))
        let waltz = makeCore(pattern: ["waltz"], mutes: allButBass).0
        let waltzHits = onsets(render(waltz, frames: 320_000), gap: 20_000)
        // 12 steps × 12 000 samples
        for (a, b) in zip(waltzHits, waltzHits.dropFirst()) { #expect(abs(b - a - 144_000) < 200) }
        #expect(waltzHits.count >= 2)

        let dixie = makeCore(pattern: ["dixie"], mutes: allButBass).0
        // Dixieland bass drum: steps 0, 4, 8, 12 — every 24 000 samples
        let hits = onsets(render(dixie, frames: 130_000), gap: 3_000)
        for (a, b) in zip(hits, hits.dropFirst()) { #expect(abs(b - a - 24_000) < 200) }
        #expect(hits.count >= 4)
    }

    @Test func switchingTimeSignatureMidRunKeepsPlaying() {
        let (core, control) = makeCore(pattern: ["rock"])
        _ = render(core, frames: 50_000)          // partway through a 16-step bar
        control.setPattern(.combine(["waltz"]))   // 12 steps: step index is past 12
        let after = render(core, frames: 100_000)
        #expect(after.contains { abs($0) > 1e-3 })
        control.setPattern(.combine(["rock"]))
        #expect(render(core, frames: 50_000).contains { abs($0) > 1e-3 })
    }

    @Test func emptyPatternStaysSilent() {
        let (core, _) = makeCore(pattern: [])
        #expect(render(core, frames: 20_000).allSatisfy { $0 == 0 })
    }

    @Test func mutedVoiceIsSilentIncludingTails() {
        let (core, control) = makeCore(pattern: ["rock"], mutes: 0xFF)
        #expect(render(core, frames: 30_000).allSatisfy { $0 == 0 })
        // Muting only the bass drum leaves the snare and cymbal audible
        control.muteMask.store(UInt8(1 << VoiceID.bd.rawValue), ordering: .relaxed)
        #expect(render(core, frames: 30_000).contains { abs($0) > 1e-3 })
    }

    @Test func stoppingSilencesTheLampAndRestartRewinds() {
        let (core, control) = makeCore(pattern: ["rock"])
        _ = render(core, frames: 10_000)
        control.running.store(false, ordering: .relaxed)
        _ = render(core, frames: 1)
        let lit = control.lampLit.load(ordering: .relaxed)
        #expect(!lit)
        // Let tails die, then restart: the downbeat sounds immediately
        _ = render(core, frames: 40_000)
        control.running.store(true, ordering: .relaxed)
        let restarted = render(core, frames: 2_000)
        #expect(restarted.contains { abs($0) > 1e-3 })
    }
}
