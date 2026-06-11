import SwiftUI

/// Center dial: token-rate needle on a 0–10 tach face with the digital
/// trip/odometer area in the lower half, mirroring the 992's center cluster.
struct GT3TachometerView: View {
    @ObservedObject var model: DashboardModel
    var diameter: CGFloat = 206

    private static let startAngle: Double = -135
    private static let sweep: Double = 270

    private var needleValue: Double {
        guard model.speedoMultiplier > 0 else { return 0 }
        return min(model.tokensPerMinute / model.speedoMultiplier, 10.35)
    }

    private var needleAngle: Double {
        DialFace.angle(for: needleValue, range: 0...10, startAngle: Self.startAngle, sweep: Self.sweep)
    }

    private var multiplierLabel: String {
        let m = model.speedoMultiplier
        if m >= 1000 {
            let k = m / 1000
            return k == k.rounded() ? "\u{00D7}\(Int(k))k" : "\u{00D7}\(k)k"
        }
        return "\u{00D7}\(Int(m))"
    }

    var body: some View {
        ZStack {
            dialBackground

            DialFace(
                range: 0...10,
                startAngle: Self.startAngle,
                sweep: Self.sweep,
                majorStep: 1,
                minorStep: 0.5,
                redZone: 9...10,
                label: { String(Int($0)) },
                tickColor: GT3Theme.tick,
                redColor: GT3Theme.red,
                numeralFont: GT3Theme.dial(diameter * 0.082, weight: .medium),
                numeralColor: GT3Theme.numeral
            )

            badge
            digitalArea

            NeedleView(angle: needleAngle, color: GT3Theme.needle, length: 0.84)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: needleAngle)
        }
        .frame(width: diameter, height: diameter)
    }

    private var dialBackground: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [GT3Theme.face, GT3Theme.face, GT3Theme.faceEdge],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [GT3Theme.bezel, Color(white: 0.06), GT3Theme.bezel.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: diameter * 0.018
                )
        }
        .shadow(color: .black.opacity(0.8), radius: 6)
    }

    private var badge: some View {
        VStack(spacing: 1) {
            Text("claude dash")
                .font(GT3Theme.dial(diameter * 0.055, weight: .semibold).italic())
                .foregroundColor(GT3Theme.badgeYellow)
            Text("TOK/MIN \(multiplierLabel)")
                .font(GT3Theme.dial(diameter * 0.035, weight: .regular))
                .foregroundColor(GT3Theme.caption)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: multiplierLabel)
        }
        .offset(y: -diameter * 0.18)
    }

    private var digitalArea: some View {
        VStack(spacing: diameter * 0.012) {
            Text(GT3Theme.formatted(Int(model.tokensPerMinute.rounded())))
                .font(GT3Theme.dial(diameter * 0.105, weight: .semibold))
                .foregroundColor(GT3Theme.lcd)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .animation(.easeOut(duration: 0.3), value: Int(model.tokensPerMinute.rounded()))

            HStack(spacing: 4) {
                Text("TRIP")
                    .font(GT3Theme.dial(diameter * 0.034, weight: .regular))
                    .foregroundColor(GT3Theme.caption)
                Text(GT3Theme.formatted(model.tripTokens))
                    .font(GT3Theme.dial(diameter * 0.048, weight: .medium))
                    .foregroundColor(GT3Theme.lcd)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.easeOut(duration: 0.4), value: model.tripTokens)
            }

            OdometerView(
                value: model.odometerTokens,
                minimumDigits: 8,
                font: GT3Theme.dial(diameter * 0.042, weight: .medium)
            )
        }
        .offset(y: diameter * 0.26)
    }
}
