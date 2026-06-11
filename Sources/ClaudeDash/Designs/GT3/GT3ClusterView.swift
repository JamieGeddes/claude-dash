import SwiftUI

/// Full 992-style cluster: large center tach with smaller 5-hour and 7-day
/// limit dials tucked behind its flanks, in a dark binnacle housing.
struct GT3ClusterView: View {
    @ObservedObject var model: DashboardModel

    private var showLimitDials: Bool { model.plan == .maxOrPro }

    var body: some View {
        ZStack {
            housing

            HStack(spacing: -16) {
                if showLimitDials {
                    GT3FuelGaugeView(
                        window: model.fiveHour,
                        stale: model.fuelStale,
                        caption: "5H"
                    )
                    .offset(y: 16)
                    .zIndex(0)
                } else {
                    // Enterprise: fuel = monthly $ quota (local estimate)
                    GT3FuelGaugeView(
                        window: model.monthlyQuota,
                        stale: false,
                        caption: "MO"
                    )
                    .offset(y: 16)
                    .zIndex(0)
                }

                GT3TachometerView(model: model)
                    .zIndex(1)

                if showLimitDials {
                    GT3FuelGaugeView(
                        window: model.sevenDay,
                        stale: model.fuelStale,
                        caption: "7D"
                    )
                    .offset(y: 16)
                    .zIndex(0)
                } else {
                    GT3SpendDialView(
                        spendUSD: model.monthlySpendUSD,
                        quotaUSD: model.monthlyQuotaUSD
                    )
                    .offset(y: 16)
                    .zIndex(0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if model.includeCacheTokens {
                Text("INCL CACHE")
                    .font(GT3Theme.dial(8, weight: .regular))
                    .foregroundColor(GT3Theme.caption)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding([.bottom, .trailing], 10)
            }
        }
    }

    private var housing: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.12), GT3Theme.housing, Color(white: 0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color(white: 0.30).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.55), radius: 14, y: 6)
    }
}

struct GT3Design: DashboardDesign {
    let id = "gt3"
    let displayName = "911 GT3"
    var preferredSize: CGSize { CGSize(width: 480, height: 244) }

    func makeView(model: DashboardModel) -> AnyView {
        AnyView(GT3ClusterView(model: model))
    }
}
