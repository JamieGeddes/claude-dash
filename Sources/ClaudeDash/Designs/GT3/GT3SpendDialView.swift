import SwiftUI

/// Small side dial showing estimated month-to-date spend against the
/// configured quota — the Enterprise counterpart to the rate-limit dials.
struct GT3SpendDialView: View {
    var spendUSD: Double
    var quotaUSD: Double // 0 = unset
    var diameter: CGFloat = 126

    private var overQuota: Bool { quotaUSD > 0 && spendUSD > quotaUSD }

    var body: some View {
        ZStack {
            dialBackground

            VStack(spacing: 2) {
                Text("EST SPEND")
                    .font(GT3Theme.dial(diameter * 0.07, weight: .regular))
                    .foregroundColor(GT3Theme.caption)
                Text(GT3Theme.currency(spendUSD))
                    .font(GT3Theme.dial(diameter * 0.155, weight: .semibold))
                    .foregroundColor(overQuota ? GT3Theme.red : GT3Theme.lcd)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.easeOut(duration: 0.4), value: Int(spendUSD * 100))
                if quotaUSD > 0 {
                    Text("of \(GT3Theme.currency(quotaUSD))/mo")
                        .font(GT3Theme.dial(diameter * 0.075, weight: .regular))
                        .foregroundColor(GT3Theme.caption)
                } else {
                    Text("this month")
                        .font(GT3Theme.dial(diameter * 0.075, weight: .regular))
                        .foregroundColor(GT3Theme.caption)
                }
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
}
