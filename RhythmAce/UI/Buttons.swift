import SwiftUI

/// Tall white rhythm key with its two-line label above.
struct RectangularButton: View {
    let pat: Pattern
    let selected: Bool
    let onPress: () -> Void

    var body: some View {
        let parts = pat.label.split(separator: " ", maxSplits: 1).map(String.init)
        Button(action: onPress) {
            Image(selected ? "rect-button-pressed" : "rect-button")
                .resizable()
                .aspectRatio(96 / 212, contentMode: .fit)
                .background(alignment: .bottom) {
                    if !selected {
                        Image("rect-shadow")
                            .resizable()
                            .frame(height: 64)
                            .offset(y: 15)
                    }
                }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                ForEach(parts, id: \.self) { part in
                    Text(part)
                        .font(.oswald(10))
                        .tracking(pat.letterSpacing)
                        .frame(height: 11)
                }
            }
            .foregroundStyle(Color.rule)
            .fixedSize()
            .frame(width: 60)
            .alignmentGuide(.top) { $0[.bottom] + 8 }  // RN: marginBottom 6; +2 for line-box offset
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(pat.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Small round push button, raised (with shadow) or pressed in.
struct RoundButton: View {
    let pressed: Bool

    var body: some View {
        Image(pressed ? "round-button-pressed" : "round-button")
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .background(alignment: .topLeading) {
                if !pressed {
                    Image("round-shadow")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .opacity(0.4)
                        .offset(y: 4)
                }
            }
    }
}

/// Round button with the diagonal leader line and underlined italic label.
struct LabeledRoundButton: View {
    let label: String
    let pressed: Bool
    let onPress: () -> Void

    var body: some View {
        Button(action: onPress) {
            ZStack(alignment: .topLeading) {
                // Diagonal connector: button bottom-right → underline left edge
                Rectangle()
                    .fill(Color.rule)
                    .frame(width: 15, height: 1)
                    .rotationEffect(.degrees(42.5))
                    .offset(x: 15, y: 26)

                // Underline, from the button's right edge to the row end
                Rectangle()
                    .fill(Color.rule)
                    .frame(height: 1)
                    .padding(.leading, 28)
                    .offset(y: 31)

                Text(label)
                    .font(.tinosBoldItalic(15))
                    .foregroundStyle(Color.ink2)
                    .padding(.leading, 40)
                    .frame(height: 29, alignment: .bottom)

                RoundButton(pressed: pressed)
            }
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label.capitalized)
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }
}
