import AVFAudio
import Foundation
import Testing
@testable import RhythmAce

extension SharedControl {
    // Atomic can't appear inside #expect expressions directly.
    var runFlag: Bool { running.load(ordering: .relaxed) }
    var stepCount: Int { steps.load(ordering: .acquiring) }
    var mutes: UInt8 { muteMask.load(ordering: .relaxed) }
}

@MainActor
struct SequencerTests {
    private func pattern(_ id: String) -> Pattern { PATTERNS.first { $0.id == id }! }

    // MARK: Pattern selection

    @Test func defaultsToRockAndPushesItToTheAudioThread() {
        let seq = Sequencer()
        #expect(seq.selected == ["rock"])
        #expect(seq.control.stepCount == 16)
        #expect(seq.combined == .combine(["rock"]))
    }

    @Test func togglingSelectsAndDeselects() {
        let seq = Sequencer()
        seq.toggleSelected(pattern("bossa"))
        #expect(seq.selected == ["rock", "bossa"])
        seq.toggleSelected(pattern("rock"))
        #expect(seq.selected == ["bossa"])
        seq.toggleSelected(pattern("bossa"))
        #expect(seq.selected.isEmpty)
        #expect(seq.control.stepCount == 0)
    }

    @Test func waltzOnlyCombinesWithWaltz() {
        let seq = Sequencer()
        seq.toggleSelected(pattern("waltz"))
        #expect(seq.selected == ["waltz"])
        #expect(seq.control.stepCount == 12)
        seq.toggleSelected(pattern("swing"))
        #expect(seq.selected == ["swing"])
        #expect(seq.control.stepCount == 16)
    }

    // MARK: Mutes, tempo, volume

    @Test func mutesMapToTheMaskBits() {
        let seq = Sequencer()
        seq.toggleMute(.bd)
        seq.toggleMute(.cb)
        #expect(seq.control.mutes == 0b0100_0001)
        seq.toggleMute(.bd)
        #expect(seq.control.mutes == 0b0100_0000)
        seq.toggleMute(.cb)
        #expect(seq.control.mutes == 0)
    }

    @Test func bpmIsRoundedAndClamped() {
        let seq = Sequencer()
        seq.setBpm(120.4)
        #expect(seq.bpm == 120)
        #expect(seq.control.bpm == 120)
        seq.setBpm(3)
        #expect(seq.bpm == 40)
        seq.setBpm(999)
        #expect(seq.bpm == 240)
        #expect(seq.control.bpm == 240)
    }

    @Test func volumeIsClamped() {
        let seq = Sequencer()
        seq.setVolume(1.7)
        #expect(seq.volume == 1)
        seq.setVolume(-0.2)
        #expect(seq.control.volume == 0)
    }

    // MARK: Start / stop / interruption

    /// The engine starts without touching the audio session at launch.
    @Test func nothingRunsUntilStart() {
        let seq = Sequencer()
        #expect(!seq.running)
        #expect(!seq.engine.isRunning)
        #expect(!seq.control.runFlag)
    }

    @Test func startAndStopTrackTheEngine() async throws {
        let seq = Sequencer()
        seq.start()
        guard seq.running else {
            // No audio hardware in this environment; the failure must be surfaced
            #expect(seq.audioError != nil)
            #expect(!seq.control.runFlag)
            return
        }
        #expect(seq.engine.isRunning)
        #expect(seq.control.runFlag)
        seq.stop()
        #expect(!seq.running)
        #expect(!seq.control.runFlag)
        // Engine lets the tails ring, then shuts down
        try await Task.sleep(for: .seconds(1))
        #expect(!seq.engine.isRunning)
    }

    @Test func interruptionStopsAndResumesOnlyWhenTheSystemSaysSo() async throws {
        let seq = Sequencer()
        seq.start()
        guard seq.running else { return }   // nothing to interrupt without hardware

        post(.began)
        try await settle()
        #expect(!seq.running)
        #expect(!seq.engine.isRunning)

        // Ended without shouldResume: stays stopped
        post(.ended, options: [])
        try await settle()
        #expect(!seq.running)

        // A resumable interruption restarts what was playing
        seq.start()
        post(.began)
        try await settle()
        post(.ended, options: .shouldResume)
        try await settle()
        #expect(seq.running)
        #expect(seq.engine.isRunning)

        // ...but not if the user hadn't started
        seq.stop()
        try await Task.sleep(for: .seconds(1))
        post(.began)
        post(.ended, options: .shouldResume)
        try await settle()
        #expect(!seq.running)
    }

    private func post(_ type: AVAudioSession.InterruptionType,
                      options: AVAudioSession.InterruptionOptions = []) {
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(),
            userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue,
                       AVAudioSessionInterruptionOptionKey: options.rawValue])
    }

    /// Notification observers are delivered on the main queue.
    private func settle() async throws { try await Task.sleep(for: .milliseconds(200)) }
}
