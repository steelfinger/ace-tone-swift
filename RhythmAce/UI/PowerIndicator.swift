import SwiftUI

/// Red lamp that pulses on each quarter note. The render thread sets
/// `lampLit` on the exact sample of the beat; we just poll it per frame.
struct PowerIndicator: View {
    let control: SharedControl
    let running: Bool

    var body: some View {
        TimelineView(.animation(paused: !running)) { _ in
            let lit = running && control.lampLit.load(ordering: .relaxed)
            Image(lit ? "red-light-on" : "red-light-off")
                .resizable()
                .scaledToFit()
        }
        .frame(width: 32, height: 32)
        .accessibilityHidden(true)
    }
}
