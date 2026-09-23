import SwiftUI

private let MUTE_VOICES: [(id: VoiceID, label: String)] = [
    (.cy, "CYMBAL"),
    (.cl, "CLAVES"),
    (.cb, "COW BELL"),
    (.bd, "BASS DRUM"),
]

/// Main screen. Proportions follow the RN layout, where percentage
/// paddings/margins resolve against the screen width.
struct PanelView: View {
    @Environment(Sequencer.self) private var seq

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // Keep 40pt clearance without a home indicator; clear it when present.
            let bottomClearance = max(40, geo.safeAreaInsets.bottom + 8)

            VStack(spacing: 0) {
                header(w)
                    .padding(.top, w * 0.36)
                    .padding(.bottom, w * 0.02)

                patternGrid(w)
                    .padding(.top, w * 0.03)

                HStack(alignment: .top, spacing: 0) {
                    cancelColumn
                    dialColumn
                }
                .padding(.top, w * 0.02)
                .padding(.leading, 20)
                .padding(.trailing, 40)
                .padding(.bottom, bottomClearance)
                .frame(maxHeight: .infinity)
            }
            .frame(width: w)
            .ignoresSafeArea(edges: .bottom)
        }
        .background {
            Image("background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Header

    private func header(_ w: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("RHYTHM ACE")
                    .font(.stardosStencil(32))
                    .tracking(1)
                Text("  FULL AUTO")
                    .font(.bebasNeue(14))
                    .tracking(1)
            }
            .foregroundStyle(Color.ink)
            Rectangle().fill(Color.rule).frame(height: 1)
        }
        .padding(.horizontal, w * 0.05)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rhythm keys

    private func patternGrid(_ w: CGFloat) -> some View {
        VStack(spacing: 0) {
            patternRow(PATTERNS[0..<8], w)
            Color.clear.frame(height: w * 0.04)
            patternRow(PATTERNS[8..<16], w)
        }
    }

    private func patternRow(_ pats: ArraySlice<Pattern>, _ w: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(pats) { pat in
                RectangularButton(pat: pat, selected: seq.selected.contains(pat.id)) {
                    seq.toggleSelected(pat)
                }
            }
        }
        .frame(width: w * 0.95)
        .padding(.top, w * 0.05)
    }

    // MARK: Cancel + Start

    private var cancelColumn: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(MUTE_VOICES, id: \.id) { v in
                LabeledRoundButton(label: v.label, pressed: seq.mutes.contains(v.id)) {
                    seq.toggleMute(v.id)
                }
            }
            Spacer(minLength: 0)
            LabeledRoundButton(label: "START", pressed: seq.running) {
                seq.running.toggle()
            }
            .padding(.bottom, 16)
        }
        .padding(.top, 20)
        .padding(.leading, 16)
        .overlay(alignment: .topLeading) {
            Text("CANCEL")
                .font(.tinosBoldItalic(15))
                .foregroundStyle(Color.ink2)
                .frame(width: 70)
                .offset(y: -8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Knobs

    private var dialColumn: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // TEMPO
            VStack(spacing: 0) {
                knobLabel("TEMPO")
                knob(size: 82, shadow: 80, image: "black-knob",
                     range: 40...240, value: seq.bpm, onChange: seq.setBpm)
                    .padding(.top, 20)
            }
            .background(alignment: .top) {
                scale("tempo-scale", size: 136).offset(y: 5)
            }
            .padding(.bottom, 10)

            // VOLUME
            VStack(spacing: 0) {
                knobLabel("VOLUME")
                knob(size: 90, shadow: 90, image: "silver-knob",
                     range: 0...1, value: seq.volume, onChange: { seq.volume = $0 })
                    .padding(.top, 10)
            }
            .background(alignment: .top) {
                scale("volume-scale", size: 112).offset(y: 19)
            }
            .overlay(alignment: .topTrailing) {
                PowerIndicator(control: seq.control, running: seq.running)
                    .offset(x: 26, y: -20)
            }
            .overlay(alignment: .bottomLeading) {
                Text("OFF")
                    .font(.tinosBoldItalic(12))
                    .foregroundStyle(.black)
                    .offset(x: -25, y: 5)
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    }

    private func knobLabel(_ s: String) -> some View {
        Text(s)
            .font(.tinosBoldItalic(14))
            .foregroundStyle(Color.ink)
            .frame(height: 20)
            .padding(.top, -4)
            .padding(.bottom, 4)
    }

    private func scale(_ name: String, size: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    private func knob(size: CGFloat, shadow: CGFloat, image: String,
                      range: ClosedRange<Double>, value: Double,
                      onChange: @escaping (Double) -> Void) -> some View {
        KnobView(range: range, value: value, onChange: onChange, image: image)
            .frame(width: size, height: size)
            .background(alignment: .top) {
                Image("round-shadow")
                    .resizable()
                    .frame(width: shadow, height: shadow)
                    .opacity(0.7)
                    .offset(y: 15)
            }
    }
}
