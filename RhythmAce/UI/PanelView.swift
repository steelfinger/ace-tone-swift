import SwiftUI

let MUTE_VOICES: [(id: VoiceID, label: String)] = [
    (.cy, "CYMBAL"),
    (.cl, "CLAVES"),
    (.cb, "COW BELL"),
    (.bd, "BASS DRUM"),
]

/// Main screen. Proportions follow the RN layout, where percentage
/// paddings/margins resolve against the screen width.
struct PanelView: View {
    @Environment(Sequencer.self) private var seq
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // The panel is a fixed-proportion graphic, so it keeps its fixed-size
        // fonts. Large text switches to a plain, scrollable layout instead.
        Group {
            if typeSize >= .xxLarge {
                LargeTextPanelView()
            } else {
                classicPanel
            }
        }
        .alert("Can't start audio", isPresented: audioErrorBinding, presenting: seq.audioError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var audioErrorBinding: Binding<Bool> {
        Binding(get: { seq.audioError != nil },
                set: { if !$0 { seq.dismissAudioError() } })
    }

    private var classicPanel: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height + geo.safeAreaInsets.bottom   // full screen height
            // Keep 40pt clearance without a home indicator; clear it when present.
            let bottomClearance = max(40, geo.safeAreaInsets.bottom + 8)
            let grid = GridMetrics(width: w, height: h)
            // RN: rows have marginBottom '3%' of the column's inner width
            let rowGap = 0.03 * ((w - 60) / 2 - 16)

            VStack(spacing: 0) {
                header(w)
                    .padding(.top, w * 0.36)
                    .padding(.bottom, w * 0.02)

                patternGrid(w, grid)
                    .padding(.top, w * 0.03)

                HStack(alignment: .top, spacing: 0) {
                    cancelColumn(rowGap: rowGap)
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
            Image(.background)
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

    /// Reproduces how Yoga resolved the RN layout's `height: '4%'` spacer
    /// between the rows (verified against RN screenshots on 3 screen sizes):
    /// the grid section is first sized with 4% of the height available
    /// below the header, then the spacer re-resolves to 4% of the grid
    /// section's own height. The remainder ends up as space below row 2.
    struct GridMetrics {
        let spacer: CGFloat
        let below: CGFloat

        init(width w: CGFloat, height h: CGFloat) {
            let rowHeight = w * 0.95 / 8 * 212 / 96
            let firstPass = 0.04 * (h - 0.36 * w)
            let section = 2 * (0.05 * w + rowHeight) + firstPass
            spacer = 0.04 * section
            below = max(0, firstPass - spacer)
        }
    }

    private func patternGrid(_ w: CGFloat, _ m: GridMetrics) -> some View {
        VStack(spacing: 0) {
            patternRow(PATTERNS[0..<8], w)
            Color.clear.frame(height: m.spacer)
            patternRow(PATTERNS[8..<16], w)
            Color.clear.frame(height: m.below)
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

    private func cancelColumn(rowGap: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: rowGap) {
            ForEach(MUTE_VOICES, id: \.id) { v in
                LabeledRoundButton(label: v.label, pressed: seq.mutes.contains(v.id)) {
                    seq.toggleMute(v.id)
                }
            }
            Spacer(minLength: 0)
            LabeledRoundButton(label: "START", pressed: seq.running) {
                seq.toggleRunning()
            }
            .padding(.bottom, 16 + rowGap)
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
                knob(size: 82, shadow: 80, image: .blackKnob,
                     range: Sequencer.bpmRange, value: seq.bpm, onChange: seq.setBpm,
                     label: "Tempo", valueText: { "\(Int($0.rounded())) beats per minute" })
                    .padding(.top, 20)
            }
            .background(alignment: .top) {
                scale(.tempoScale, size: 136).offset(y: 5)
            }
            .padding(.bottom, 10)

            // VOLUME
            VStack(spacing: 0) {
                knobLabel("VOLUME")
                knob(size: 90, shadow: 90, image: .silverKnob,
                     range: 0...1, value: seq.volume, onChange: seq.setVolume,
                     label: "Volume", valueText: { "\(Int(($0 * 100).rounded())) percent" })
                    .padding(.top, 10)
            }
            .background(alignment: .top) {
                scale(.volumeScale, size: 112).offset(y: 19)
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

    private func scale(_ name: ImageResource, size: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .allowsHitTesting(false)
    }

    private func knob(size: CGFloat, shadow: CGFloat, image: ImageResource,
                      range: ClosedRange<Double>, value: Double,
                      onChange: @escaping (Double) -> Void,
                      label: LocalizedStringKey,
                      valueText: @escaping (Double) -> String) -> some View {
        KnobView(range: range, value: value, onChange: onChange, image: image,
                 label: label, valueText: valueText)
            .frame(width: size, height: size)
            .background(alignment: .top) {
                Image(.roundShadow)
                    .resizable()
                    .frame(width: shadow, height: shadow)
                    .opacity(0.7)
                    .offset(y: 15)
            }
    }
}
