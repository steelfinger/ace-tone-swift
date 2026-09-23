import SwiftUI

/// Rotary knob: drag around the centre to turn. -135° at min, +135° at max.
/// Half a turn of finger travel sweeps the full range, as in the RN version.
struct KnobView: View {
    let range: ClosedRange<Double>
    let value: Double
    let onChange: (Double) -> Void
    let image: String

    @State private var start: (angle: Double, value: Double)?

    private var span: Double { range.upperBound - range.lowerBound }
    private var rotation: Double { (value - range.lowerBound) / span * 270 - 135 }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Image(image)
                .resizable()
                .scaledToFit()
                .rotationEffect(.degrees(rotation))
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let angle = atan2(g.location.y - center.y, g.location.x - center.x)
                            if start == nil {
                                let a0 = atan2(g.startLocation.y - center.y, g.startLocation.x - center.x)
                                start = (a0, value)
                            }
                            guard let start else { return }
                            var delta = angle - start.angle
                            if delta > .pi { delta -= 2 * .pi }
                            if delta < -.pi { delta += 2 * .pi }
                            let next = start.value + delta * span / .pi
                            onChange(min(range.upperBound, max(range.lowerBound, next)))
                        }
                        .onEnded { _ in start = nil }
                )
        }
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(value.rounded()))"))
        .accessibilityAdjustableAction { dir in
            let stepSize = span / 20
            let next = dir == .increment ? value + stepSize : value - stepSize
            onChange(min(range.upperBound, max(range.lowerBound, next)))
        }
    }
}
