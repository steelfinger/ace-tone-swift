import SwiftUI

/// Layout for accessibility text sizes, where the fixed-proportion panel
/// can't hold scaled text. Same controls, standard components.
struct LargeTextPanelView: View {
    @Environment(Sequencer.self) private var seq

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("RHYTHM ACE")
                    .font(.custom("StardosStencil-Bold", size: 32, relativeTo: .largeTitle))
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)

                Button {
                    seq.toggleRunning()
                } label: {
                    Text(seq.running ? "STOP" : "START")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(seq.running ? .gray : .red)

                section("Rhythm") {
                    ForEach(PATTERNS) { pat in
                        toggleRow(pat.name, isOn: seq.selected.contains(pat.id)) {
                            seq.toggleSelected(pat)
                        }
                    }
                }

                section("Cancel") {
                    ForEach(MUTE_VOICES, id: \.id) { v in
                        toggleRow(v.label.capitalized, isOn: seq.mutes.contains(v.id)) {
                            seq.toggleMute(v.id)
                        }
                    }
                }

                section("Tempo") {
                    Slider(value: Binding(get: { seq.bpm }, set: seq.setBpm),
                           in: Sequencer.bpmRange, step: 1) { Text("Tempo") }
                        .accessibilityValue("\(Int(seq.bpm)) beats per minute")
                    Text("\(Int(seq.bpm)) BPM").font(.body.monospacedDigit())
                }

                section("Volume") {
                    Slider(value: Binding(get: { seq.volume }, set: seq.setVolume),
                           in: 0...1) { Text("Volume") }
                        .accessibilityValue("\(Int((seq.volume * 100).rounded())) percent")
                }
            }
            .padding()
            .foregroundStyle(Color.ink)
        }
        .background(Color(red: 0.93, green: 0.90, blue: 0.83).ignoresSafeArea())
    }

    private func section<Content: View>(_ title: LocalizedStringKey,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Tinos-BoldItalic", size: 20, relativeTo: .title3))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func toggleRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
