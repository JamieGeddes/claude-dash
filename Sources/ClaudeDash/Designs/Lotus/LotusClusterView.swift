import SwiftUI

/// Full Exige S2 cluster: tach (tokens/min) and speedo (5h window fuel) under
/// the double-hump cowl, amber trip LCD bottom-left, warning lights bottom-
/// right. Enterprise swaps the fuel data for monthly spend, like GT3.
struct LotusClusterView: View {
    @ObservedObject var model: DashboardModel

    /// Cowl geometry is coupled to the 500×260 preferredSize — hump tops sit
    /// at y≈2; re-check clipping if any of these move.
    private enum Layout {
        static let dialDiameter: CGFloat = 188
        static let leftCenter = CGPoint(x: 134, y: 122)
        static let rightCenter = CGPoint(x: 366, y: 122)
        static let humpRadius: CGFloat = 120
        static let apron = CGRect(x: 0, y: 122, width: 500, height: 138)
        static let lcdCenter = CGPoint(x: 134, y: 230)
        static let lampsCenter = CGPoint(x: 366, y: 237)
    }

    private var showLimitData: Bool { model.plan == .maxOrPro }

    var body: some View {
        ZStack {
            LotusHousingView(
                leftCenter: Layout.leftCenter,
                rightCenter: Layout.rightCenter,
                humpRadius: Layout.humpRadius,
                apron: Layout.apron
            )

            LotusSpeedoView(
                window: showLimitData ? model.fiveHour : model.monthlyQuota,
                stale: showLimitData ? model.fuelStale : false,
                caption: showLimitData ? "5H" : "MO",
                diameter: Layout.dialDiameter
            )
            .position(Layout.rightCenter)

            LotusTachView(model: model, diameter: Layout.dialDiameter)
                .position(Layout.leftCenter)

            LotusLCDPanel(
                trip: model.tripTokens,
                odometer: model.odometerTokens,
                bar: showLimitData ? model.sevenDay : model.monthlyQuota,
                stale: showLimitData ? model.fuelStale : false,
                enterpriseSpend: showLimitData ? nil : model.monthlySpendUSD
            )
            .position(Layout.lcdCenter)

            LotusWarningLights(
                fuelLow: showLimitData && (model.fiveHour?.remainingPercentage ?? 100) < 15,
                engineOn: showLimitData && model.fuelStale,
                batteryOn: model.tokensPerMinute == 0
            )
            .position(Layout.lampsCenter)

            if model.includeCacheTokens {
                Text("INCL CACHE")
                    .font(LotusTheme.dial(8, weight: .regular))
                    .foregroundColor(LotusTheme.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding([.bottom, .trailing], 10)
            }
        }
    }
}

struct LotusDesign: DashboardDesign {
    let id = "lotus"
    let displayName = "Lotus Exige"
    var preferredSize: CGSize { CGSize(width: 500, height: 260) }

    func makeView(model: DashboardModel) -> AnyView {
        AnyView(LotusClusterView(model: model))
    }
}
