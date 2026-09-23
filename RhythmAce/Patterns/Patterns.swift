import Foundation

struct Pattern: Identifiable, Sendable {
    let id: String
    let name: String
    var displayName: String? = nil
    var letterSpacing: CGFloat = 0
    let steps: Int                    // 12 (waltz, 3/4) or 16
    let grid: [VoiceID: UInt16]       // bit i = hit on step i; missing voice = all rests

    var label: String { (displayName ?? name).uppercased() }
}

/// "1...1...1...1..." → bitmask with bit i set for each '1'.
private func p(_ s: String) -> UInt16 {
    var bits: UInt16 = 0
    for (i, c) in s.enumerated() where c == "1" { bits |= 1 << i }
    return bits
}

/// Result of OR-combining the selected patterns (the FR-1's diode matrix).
/// Packed so the audio thread can read it with plain atomic loads.
struct CombinedPattern: Equatable, Sendable {
    var steps: Int = 0                // 0 = nothing selected
    var rows = [UInt16](repeating: 0, count: VoiceID.allCases.count)

    /// Voices 0–3 in the low word, 4–7 in the high word, 16 bits each.
    var packed: (lo: UInt64, hi: UInt64) {
        var lo: UInt64 = 0, hi: UInt64 = 0
        for (i, row) in rows.enumerated() {
            if i < 4 { lo |= UInt64(row) << (16 * i) } else { hi |= UInt64(row) << (16 * (i - 4)) }
        }
        return (lo, hi)
    }

    static func combine(_ ids: [String]) -> CombinedPattern {
        let chosen = PATTERNS.filter { ids.contains($0.id) }
        guard let first = chosen.first else { return CombinedPattern() }
        // Ignore patterns that don't match the dominant time signature
        var out = CombinedPattern(steps: first.steps)
        for pat in chosen where pat.steps == first.steps {
            for (voice, row) in pat.grid { out.rows[voice.rawValue] |= row }
        }
        return out
    }
}

// Patterns transcribed by ear from FR-1 demos — treat as starting point,
// refine against reference recordings. Source: FR-1 demo listening sessions.
let PATTERNS: [Pattern] = [
    Pattern(id: "waltz", name: "Waltz", steps: 12, grid: [
        .bd: p("1..........."),
        .sd: p("....1...1..."),
        .cy: p("1...1...1..."),
        .mc: p("..1...1...1."),
    ]),
    Pattern(id: "dixie", name: "Dixieland", displayName: "Dixie land", steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cy: p("1.1.1.1.1.1.1.1."),
        .cl: p("..1...1...1...1."),
    ]),
    Pattern(id: "western", name: "Western", letterSpacing: -0.6, steps: 16, grid: [
        .bd: p("1.......1......."),
        .sd: p("....1.......1..."),
        .cb: p("1...1...1...1..."),
        .mc: p("..1...1...1...1."),
    ]),
    Pattern(id: "rock", name: "Rock'n Roll", letterSpacing: -0.2, steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cy: p("1.1.1.1.1.1.1.1."),
    ]),
    Pattern(id: "slowrock", name: "Slow Rock", steps: 16, grid: [
        .bd: p("1.......1......."),
        .sd: p("....1.......1..."),
        .cy: p("1.1.1.1.1.1.1.1."),
    ]),
    Pattern(id: "bossa", name: "Bosa Nova", steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cl: p("1..1..1...1.1..."),
        .mc: p("..1...1...1...1."),
    ]),
    Pattern(id: "foxtrot", name: "Fox Trot", steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cy: p("..1...1...1...1."),
    ]),
    Pattern(id: "swing", name: "Swing", steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cy: p("1..1.11..1.11..1"), // swung ride feel
    ]),
    Pattern(id: "tango", name: "Tango", steps: 16, grid: [
        .bd: p("1.......1......."),
        .sd: p("......1.....1.1."),
        .cl: p("1...1...1...1.1."),
    ]),
    Pattern(id: "beguine", name: "Beguine", letterSpacing: -0.6, steps: 16, grid: [
        .bd: p("1.....1.1.....1."),
        .lc: p("....1.......1..."),
        .cl: p("1...1.1.1...1.1."),
        .mc: p("..1...1...1...1."),
    ]),
    Pattern(id: "rhumba", name: "Rhumba", letterSpacing: -0.4, steps: 16, grid: [
        .bd: p("1.....1...1....."),
        .sd: p("....1.......1..."),
        .cl: p("1..1..1...1.1..."),
        .mc: p("..1...1...1...1."),
    ]),
    Pattern(id: "samba", name: "Samba", steps: 16, grid: [
        .bd: p("1..1..1.1..1..1."),
        .sd: p("....1.......1..."),
        .cb: p("1...1...1...1..."),
        .mc: p(".1.1.1.1.1.1.1.1"),
    ]),
    Pattern(id: "mambo", name: "Mambo", steps: 16, grid: [
        .bd: p("1.....1.1.....1."),
        .sd: p("....1.......1..."),
        .cb: p("1...1.1.1...1.1."),
        .lc: p("......1.......1."),
    ]),
    Pattern(id: "chacha", name: "Cha-Cha", letterSpacing: -0.6, steps: 16, grid: [
        .bd: p("1...1...1...1.1."),
        .sd: p("....1.......1..."),
        .cb: p("1.1.1.1.1.1.1.1."),
        .mc: p("..1...1...1...1."),
    ]),
    Pattern(id: "sniffle", name: "Sniffle", letterSpacing: -0.4, steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("....1.......1..."),
        .cy: p("1.1.1.1.1.1.1.1."),
        .cl: p("..1...1...1...1."),
    ]),
    Pattern(id: "march", name: "March", steps: 16, grid: [
        .bd: p("1...1...1...1..."),
        .sd: p("..1.1.1.1.1.1.1."),
        .cy: p("1...1...1...1..."),
    ]),
]
