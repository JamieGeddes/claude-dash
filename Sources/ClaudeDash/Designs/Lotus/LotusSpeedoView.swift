import SwiftUI

/// Right dial: the Exige's 0–160 speedo face repurposed as a fuel gauge for a
/// rate-limit window — 160 = full window remaining, 0 = limit reached. A small
/// decorative inner km/h ring keeps the donor cluster's look.
struct LotusSpeedoView: View {
    var window: RateLimitWindow?
    var stale: Bool
    var caption: String        // "5H" or "MO"
    var diameter: CGFloat = 188

    private static let startAngle: Double = -135
    private static let sweep: Double = 270

    private var remaining: Double { window?.remainingPercentage ?? 0 }
    private var hasData: Bool { window != nil }
    private var isLow: Bool { hasData && remaining < 15 }

    private var needleAngle: Double {
        DialFace.angle(for: remaining * 1.6, range: 0...160, startAngle: Self.startAngle, sweep: Self.sweep)
    }

    var body: some View {
        ZStack {
            LotusDialBackground(diameter: diameter)

            DialFace(
                range: 0...160,
                startAngle: Self.startAngle,
                sweep: Self.sweep,
                majorStep: 20,
                minorStep: 10,
                redZone: nil,
                label: { String(Int($0)) },
                tickColor: LotusTheme.ink,
                redColor: LotusTheme.needleRed,
                numeralFont: LotusTheme.numeral(diameter * 0.082),
                numeralColor: LotusTheme.ink,
                labelRadius: 0.68
            )

            // Decorative inner km/h ring, as on the donor cluster.
            DialFace(
                range: 0...260,
                startAngle: Self.startAngle,
                sweep: Self.sweep,
                majorStep: 20,
                minorStep: nil,
                redZone: nil,
                label: { $0 == 0 ? nil : String(Int($0)) },
                tickColor: LotusTheme.inkSoft,
                redColor: LotusTheme.needleRed,
                numeralFont: LotusTheme.numeral(diameter * 0.036),
                numeralColor: LotusTheme.inkSoft,
                majorTickLength: 0.03,
                tickInset: 0.42,
                labelRadius: 0.46
            )

            // KM/H sits below the hub, above the MPH-position caption.
            Text("KM/H")
                .font(LotusTheme.dial(diameter * 0.038, weight: .regular))
                .foregroundColor(LotusTheme.inkSoft)
                .offset(y: diameter * 0.13)

            captionBlock
                .offset(y: diameter * 0.23)

            if hasData {
                NeedleView(
                    angle: needleAngle,
                    color: LotusTheme.needleRed,
                    length: 0.80,
                    hubColor: LotusTheme.hub
                )
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: needleAngle)
                .opacity(stale ? 0.5 : 1)
            }

            // Dimming a white face with opacity would expose the dark cowl;
            // wash it out with a grey veil instead.
            if stale || !hasData {
                Circle()
                    .fill(Color(white: 0.45).opacity(0.35))
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var captionBlock: some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "fuelpump.fill")
                    .font(.system(size: diameter * 0.045))
                    .foregroundColor(isLow ? LotusTheme.needleRed : LotusTheme.inkSoft)
                Text(caption)
                    .font(LotusTheme.dial(diameter * 0.052, weight: .semibold))
                    .foregroundColor(LotusTheme.ink)
                if stale, hasData {
                    Circle()
                        .fill(LotusTheme.staleAmber)
                        .frame(width: diameter * 0.035, height: diameter * 0.035)
                }
            }
            if let window {
                resetCountdown(window)
            } else {
                Text("--")
                    .font(LotusTheme.dial(diameter * 0.05, weight: .regular))
                    .foregroundColor(LotusTheme.inkSoft)
            }
        }
    }

    @ViewBuilder
    private func resetCountdown(_ window: RateLimitWindow) -> some View {
        if let resetsAt = window.resetsAt {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let seconds = resetsAt.timeIntervalSince(context.date)
                if seconds > 0 {
                    Text(Self.countdown(seconds))
                        .font(LotusTheme.dial(diameter * 0.046, weight: .regular))
                        .foregroundColor(LotusTheme.inkSoft)
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
