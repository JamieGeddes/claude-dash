import SwiftUI

/// Small side dial showing remaining capacity of a rate-limit window as a
/// fuel gauge: F = untouched window, E = limit reached. Red zone near E and a
/// low-fuel lamp below 15%.
struct GT3FuelGaugeView: View {
    var window: RateLimitWindow?
    var stale: Bool
    var caption: String        // "5H" or "7D"
    var diameter: CGFloat = 126

    private static let startAngle: Double = -60
    private static let sweep: Double = 120

    private var remaining: Double { window?.remainingPercentage ?? 0 }
    private var hasData: Bool { window != nil }
    private var isLow: Bool { hasData && remaining < 15 }

    private var needleAngle: Double {
        DialFace.angle(for: remaining, range: 0...100, startAngle: Self.startAngle, sweep: Self.sweep)
    }

    var body: some View {
        ZStack {
            dialBackground

            DialFace(
                range: 0...100,
                startAngle: Self.startAngle,
                sweep: Self.sweep,
                majorStep: 50,
                minorStep: 25,
                redZone: 0...12,
                label: { value in
                    switch value {
                    case 0: return "E"
                    case 100: return "F"
                    default: return nil
                    }
                },
                tickColor: GT3Theme.tick,
                redColor: GT3Theme.red,
                numeralFont: GT3Theme.dial(diameter * 0.105, weight: .medium),
                numeralColor: GT3Theme.numeral,
                labelRadius: 0.62
            )
            .opacity(hasData && !stale ? 1 : 0.45)

            captionRow
                .offset(y: -diameter * 0.21)

            centerInfo

            if hasData {
                NeedleView(angle: needleAngle, color: GT3Theme.needle, length: 0.78, hubScale: 0.11)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: needleAngle)
                    .opacity(stale ? 0.45 : 1)
            }
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
                    lineWidth: diameter * 0.02
                )
        }
        .shadow(color: .black.opacity(0.8), radius: 5)
    }

    private var captionRow: some View {
        HStack(spacing: 3) {
            Image(systemName: "fuelpump.fill")
                .font(.system(size: diameter * 0.07))
                .foregroundColor(isLow ? GT3Theme.red : GT3Theme.caption)
            Text(caption)
                .font(GT3Theme.dial(diameter * 0.08, weight: .medium))
                .foregroundColor(GT3Theme.caption)
            if stale, hasData {
                Circle()
                    .fill(GT3Theme.staleAmber)
                    .frame(width: diameter * 0.045, height: diameter * 0.045)
            }
        }
    }

    private var centerInfo: some View {
        VStack(spacing: 2) {
            if let window {
                Text("\(Int(window.remainingPercentage.rounded()))%")
                    .font(GT3Theme.dial(diameter * 0.135, weight: .semibold))
                    .foregroundColor(isLow ? GT3Theme.red : GT3Theme.lcd)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                resetCountdown(window)
            } else {
                Text("--")
                    .font(GT3Theme.dial(diameter * 0.12, weight: .medium))
                    .foregroundColor(GT3Theme.caption)
            }
        }
        .offset(y: diameter * 0.24)
    }

    @ViewBuilder
    private func resetCountdown(_ window: RateLimitWindow) -> some View {
        if let resetsAt = window.resetsAt {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let seconds = resetsAt.timeIntervalSince(context.date)
                if seconds > 0 {
                    Text(Self.countdown(seconds))
                        .font(GT3Theme.dial(diameter * 0.062, weight: .regular))
                        .foregroundColor(GT3Theme.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    private static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
