import SwiftUI

/// Left dial: token-rate needle on the Exige's 0–10 ×1000 tach face, with a
/// simplified roundel badge up top and the multiplier in the "x1000" spot.
struct LotusTachView: View {
    @ObservedObject var model: DashboardModel
    var diameter: CGFloat = 188

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
            LotusDialBackground(diameter: diameter)

            DialFace(
                range: 0...10,
                startAngle: Self.startAngle,
                sweep: Self.sweep,
                majorStep: 1,
                minorStep: 0.5,
                redZone: nil,
                label: { String(Int($0)) },
                tickColor: LotusTheme.ink,
                redColor: LotusTheme.needleRed,
                numeralFont: LotusTheme.dial(diameter * 0.095, weight: .semibold),
                numeralColor: LotusTheme.ink
            )

            LotusRoundelBadge()
                .frame(width: diameter * 0.14, height: diameter * 0.14)
                .offset(y: -diameter * 0.20)

            VStack(spacing: 1) {
                Text(multiplierLabel)
                    .font(LotusTheme.dial(diameter * 0.052, weight: .semibold))
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: multiplierLabel)
                Text("TOK/MIN")
                    .font(LotusTheme.dial(diameter * 0.046, weight: .regular))
            }
            .foregroundColor(LotusTheme.ink)
            .offset(y: diameter * 0.19)

            NeedleView(
                angle: needleAngle,
                color: LotusTheme.needleRed,
                length: 0.80,
                hubColor: LotusTheme.hub
            )
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: needleAngle)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Shared silver-white face with a dark bezel ring.
struct LotusDialBackground: View {
    var diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [LotusTheme.faceCenter, LotusTheme.faceCenter, LotusTheme.faceEdge],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(white: 0.20), LotusTheme.bezel, Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: diameter * 0.025
                )
        }
        .shadow(color: .black.opacity(0.7), radius: 6)
    }
}

/// Simplified Lotus-style roundel drawn from primitives (no trademark asset):
/// silver ring, yellow disc, green rounded triangle.
struct LotusRoundelBadge: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(LotusTheme.badgeYellow)
                Circle()
                    .strokeBorder(Color(white: 0.65), lineWidth: side * 0.07)
                RoundedTriangle()
                    .fill(LotusTheme.badgeGreen)
                    .frame(width: side * 0.62, height: side * 0.52)
                    .offset(y: side * 0.02)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }
}

private struct RoundedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) * 0.18
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        var path = Path()
        path.move(to: CGPoint(x: (top.x + bottomLeft.x) / 2, y: (top.y + bottomLeft.y) / 2))
        path.addArc(tangent1End: top, tangent2End: bottomRight, radius: r)
        path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: r)
        path.addArc(tangent1End: bottomLeft, tangent2End: top, radius: r)
        path.closeSubpath()
        return path
    }
}
