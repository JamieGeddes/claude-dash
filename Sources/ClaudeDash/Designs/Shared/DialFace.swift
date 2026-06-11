import SwiftUI

/// Parameterized analog dial face: tick marks, numerals along the arc, and an
/// optional red zone. Angles are degrees clockwise from 12 o'clock; values map
/// linearly from `range.lowerBound` at `startAngle` across `sweep`.
struct DialFace: View {
    var range: ClosedRange<Double>
    var startAngle: Double
    var sweep: Double
    var majorStep: Double
    var minorStep: Double?
    var redZone: ClosedRange<Double>?
    var label: (Double) -> String?

    var tickColor: Color = .white
    var redColor: Color = .red
    var numeralFont: Font
    var numeralColor: Color = .white

    var majorTickLength: CGFloat = 0.10   // fraction of radius
    var minorTickLength: CGFloat = 0.05
    var tickInset: CGFloat = 0.06         // from outer edge, fraction of radius
    var labelRadius: CGFloat = 0.70       // fraction of radius

    static func angle(for value: Double, range: ClosedRange<Double>, startAngle: Double, sweep: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return startAngle }
        let fraction = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / span
        return startAngle + fraction * sweep
    }

    private func point(angle: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let rad = angle * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(sin(rad)),
            y: center.y - radius * CGFloat(cos(rad))
        )
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let outer = radius * (1 - tickInset)

            // Red zone arc just inside the ticks.
            if let redZone {
                let from = Self.angle(for: redZone.lowerBound, range: range, startAngle: startAngle, sweep: sweep)
                let to = Self.angle(for: redZone.upperBound, range: range, startAngle: startAngle, sweep: sweep)
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: outer - radius * 0.012,
                    startAngle: .degrees(from - 90),
                    endAngle: .degrees(to - 90),
                    clockwise: false
                )
                context.stroke(arc, with: .color(redColor.opacity(0.85)), lineWidth: radius * 0.022)
            }

            func drawTick(value: Double, length: CGFloat, width: CGFloat, color: Color) {
                let angle = Self.angle(for: value, range: range, startAngle: startAngle, sweep: sweep)
                var path = Path()
                path.move(to: point(angle: angle, radius: outer, center: center))
                path.addLine(to: point(angle: angle, radius: outer - radius * length, center: center))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            // Minor ticks first so majors draw over them.
            if let minorStep {
                var value = range.lowerBound
                while value <= range.upperBound + 0.0001 {
                    let isMajor = (value - range.lowerBound).truncatingRemainder(dividingBy: majorStep).magnitude < 0.0001
                        || ((value - range.lowerBound).truncatingRemainder(dividingBy: majorStep) - majorStep).magnitude < 0.0001
                    if !isMajor {
                        let inRed = redZone?.contains(value) ?? false
                        drawTick(value: value, length: minorTickLength, width: max(1, radius * 0.012),
                                 color: inRed ? redColor : tickColor.opacity(0.7))
                    }
                    value += minorStep
                }
            }

            var value = range.lowerBound
            while value <= range.upperBound + 0.0001 {
                let inRed = redZone?.contains(value) ?? false
                drawTick(value: value, length: majorTickLength, width: max(1.5, radius * 0.022),
                         color: inRed ? redColor : tickColor)
                if let text = label(value) {
                    let position = point(angle: Self.angle(for: value, range: range, startAngle: startAngle, sweep: sweep),
                                         radius: radius * labelRadius, center: center)
                    context.draw(
                        Text(text).font(numeralFont).foregroundColor(inRed ? redColor : numeralColor),
                        at: position
                    )
                }
                value += majorStep
            }
        }
    }
}
