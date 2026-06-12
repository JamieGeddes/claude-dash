import SwiftUI

/// The Exige's two-row warning-light strip. Everything renders dim for
/// authenticity; three lamps are live: fuel (5h window low), check-engine
/// (stale statusline data), and battery (no token activity).
struct LotusWarningLights: View {
    var fuelLow: Bool
    var engineOn: Bool
    var batteryOn: Bool

    private struct Lamp: Identifiable {
        var id: String { symbol }   // symbols are unique within each row
        let symbol: String
        var onColor: Color = LotusTheme.lampAmber
        var isOn: Bool = false
    }

    private var topRow: [Lamp] {
        [
            Lamp(symbol: "arrowtriangle.left.fill", onColor: .green),
            Lamp(symbol: "arrowtriangle.right.fill", onColor: .green),
            Lamp(symbol: "figure.seated.seatbelt", onColor: LotusTheme.lampRed),
            Lamp(symbol: "brakesignal", onColor: LotusTheme.lampRed),
            Lamp(symbol: "oilcan.fill", onColor: LotusTheme.lampRed),
            Lamp(symbol: "fuelpump.fill", onColor: LotusTheme.lampAmber, isOn: fuelLow),
        ]
    }

    private var bottomRow: [Lamp] {
        [
            Lamp(symbol: "abs.brakesignal", onColor: LotusTheme.lampAmber),
            Lamp(symbol: "headlight.low.beam.fill", onColor: .green),
            Lamp(symbol: "headlight.fog.fill", onColor: .green),
            Lamp(symbol: "minus.plus.batteryblock.fill", onColor: LotusTheme.lampRed, isOn: batteryOn),
            Lamp(symbol: "car.top.door.front.left.open", onColor: LotusTheme.lampRed),
            Lamp(symbol: "engine.combustion.fill", onColor: LotusTheme.lampAmber, isOn: engineOn),
        ]
    }

    var body: some View {
        VStack(spacing: 5) {
            lampRow(topRow)
            lampRow(bottomRow)
        }
    }

    private func lampRow(_ lamps: [Lamp]) -> some View {
        HStack(spacing: 10) {
            ForEach(lamps) { lamp in
                Image(systemName: lamp.symbol)
                    .font(.system(size: 10))
                    .foregroundColor(lamp.isOn ? lamp.onColor : LotusTheme.lampOff)
                    .shadow(color: lamp.isOn ? lamp.onColor.opacity(0.8) : .clear, radius: 3)
            }
        }
    }
}
