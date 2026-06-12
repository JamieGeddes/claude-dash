import SwiftUI

/// Amber trip LCD set into the lower tach face, like the donor cluster:
/// line 1 = trip tokens + segmented fuel bar (7-day window) + pump icon,
/// line 2 = zero-padded odometer. Enterprise swaps the trip for est. spend.
struct LotusLCDPanel: View {
    var trip: Int
    var odometer: Int
    var bar: RateLimitWindow?
    var stale: Bool
    var enterpriseSpend: Double?   // nil on Max/Pro

    private let panelSize = CGSize(width: 150, height: 46)

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(line1Text)
                        .font(LotusTheme.lcd(13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.easeOut(duration: 0.4), value: line1Text)
                    Spacer(minLength: 0)
                    HStack(spacing: 3) {
                        SegmentBar(remaining: bar?.remainingPercentage)
                        if enterpriseSpend == nil {
                            Image(systemName: "fuelpump.fill")
                                .font(.system(size: 9))
                        }
                    }
                    .opacity(stale ? 0.5 : 1)
                }
                Text(String(format: "%08d", odometer))
                    .font(LotusTheme.lcd(12))
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.easeOut(duration: 0.5), value: odometer)
            }
            .foregroundColor(LotusTheme.lcdInk)
            .padding(.horizontal, 9)
        }
        .frame(width: panelSize.width, height: panelSize.height)
    }

    private var line1Text: String {
        if let enterpriseSpend {
            return "EST \(LotusTheme.currency(enterpriseSpend))"
        }
        return LotusTheme.lcdCompact(trip)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [LotusTheme.lcdTop, LotusTheme.lcdBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // Recessed look: shadow cast by the bezel onto the glass.
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
                .clipShape(RoundedRectangle(cornerRadius: 3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color(white: 0.05), lineWidth: 2)
            )
    }
}

/// Five-segment fuel bar: filled squares for remaining capacity, outlined
/// squares for the spent portion. All outlined when no data.
private struct SegmentBar: View {
    var remaining: Double?   // 0–100, nil = no data

    private var litCount: Int {
        guard let remaining else { return 0 }
        return Int((remaining / 100 * 5).rounded(.up))
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index < litCount ? LotusTheme.lcdInk : LotusTheme.lcdInk.opacity(0.15))
                    .overlay(Rectangle().strokeBorder(LotusTheme.lcdInk.opacity(0.6), lineWidth: 0.5))
                    .frame(width: 9, height: 10)
            }
        }
    }
}
