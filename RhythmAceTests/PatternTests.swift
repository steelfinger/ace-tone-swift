import Testing
@testable import RhythmAce

struct PatternTests {
    private func pattern(_ id: String) -> Pattern { PATTERNS.first { $0.id == id }! }

    @Test func sixteenPresetsWithValidStepCounts() {
        #expect(PATTERNS.count == 16)
        #expect(Set(PATTERNS.map(\.id)).count == 16)
        for pat in PATTERNS {
            #expect(pat.steps == 12 || pat.steps == 16)
            // No hits beyond the pattern's last step
            for row in pat.grid.values where pat.steps == 12 {
                #expect(row >> 12 == 0, "\(pat.name) has hits past step 12")
            }
        }
    }

    @Test func emptySelectionIsSilent() {
        let c = CombinedPattern.combine([])
        #expect(c.steps == 0)
        #expect(c.packed == (0, 0))
    }

    @Test func singlePatternKeepsItsRows() {
        let rock = pattern("rock")
        let c = CombinedPattern.combine(["rock"])
        #expect(c.steps == 16)
        for voice in VoiceID.allCases {
            #expect(c.rows[voice.rawValue] == (rock.grid[voice] ?? 0))
        }
    }

    @Test func combiningORsTheRows() {
        let a = pattern("rock"), b = pattern("bossa")
        let c = CombinedPattern.combine(["rock", "bossa"])
        for voice in VoiceID.allCases {
            #expect(c.rows[voice.rawValue] == (a.grid[voice] ?? 0) | (b.grid[voice] ?? 0))
        }
    }

    @Test func combineIgnoresTimeSignatureMismatch() {
        // 12-step Waltz is first in PATTERNS, so it sets the signature
        let c = CombinedPattern.combine(["rock", "waltz"])
        #expect(c.steps == 12)
        #expect(c == CombinedPattern.combine(["waltz"]))
        // Selection order doesn't matter, only list order
        #expect(CombinedPattern.combine(["waltz", "rock"]) == c)
    }

    @Test func packingPutsFourVoicesPerWord() {
        var c = CombinedPattern(steps: 16)
        c.rows[VoiceID.bd.rawValue] = 0x0001
        c.rows[VoiceID.hc.rawValue] = 0x8000
        c.rows[VoiceID.cy.rawValue] = 0x1234
        c.rows[VoiceID.mc.rawValue] = 0xFFFF
        let (lo, hi) = c.packed
        #expect(lo == 0x8000_0000_0000_0001)
        #expect(hi == 0xFFFF_0000_0000_1234)
    }
}
