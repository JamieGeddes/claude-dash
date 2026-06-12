import SwiftUI

/// Palette and typography for the Exige S2 cluster: silver-white faces, black
/// markings, red needles, amber trip LCD, dark double-hump binnacle.
enum LotusTheme {
    // Dial faces
    static let faceCenter = Color(red: 0.92, green: 0.92, blue: 0.91)
    static let faceEdge = Color(red: 0.78, green: 0.78, blue: 0.77)
    static let ink = Color(white: 0.10)
    static let inkSoft = Color(white: 0.10).opacity(0.7)
    static let needleRed = Color(red: 0.86, green: 0.07, blue: 0.10)
    static let hub = Color(white: 0.10)
    static let bezel = Color(white: 0.08)

    // Binnacle
    static let cowlTop = Color(white: 0.13)
    static let cowl = Color(white: 0.06)
    static let innerPanel = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let caption = Color(white: 0.55)

    // Amber LCD
    static let lcdTop = Color(red: 0.95, green: 0.66, blue: 0.12)
    static let lcdBottom = Color(red: 0.85, green: 0.55, blue: 0.05)
    static let lcdInk = Color(red: 0.16, green: 0.10, blue: 0.01)

    // Warning lamps
    static let lampOff = Color(white: 0.33)
    static let lampAmber = Color(red: 1.0, green: 0.65, blue: 0.05)
    static let lampRed = Color(red: 0.95, green: 0.15, blue: 0.10)
    static let staleAmber = Color(red: 1.0, green: 0.7, blue: 0.1)

    // Roundel badge
    static let badgeYellow = Color(red: 0.98, green: 0.83, blue: 0.05)
    static let badgeGreen = Color(red: 0.0, green: 0.35, blue: 0.16)

    /// The Exige's humanist dial numerals are closest to Gill Sans, which
    /// ships with macOS; fall back to the bundled Saira SemiCondensed.
    static func dial(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let candidates: [String]
        switch weight {
        case .semibold, .bold:
            candidates = ["GillSans-SemiBold", "GillSans-Bold", "SairaSemiCondensed-SemiBold"]
        case .regular, .light:
            candidates = ["GillSans", "SairaSemiCondensed-Regular"]
        default:
            candidates = ["GillSans", "SairaSemiCondensed-Medium"]
        }
        return FontLoader.font(candidates: candidates, size: size, weight: weight)
    }

    static func lcd(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }

    static func currency(_ usd: Double) -> String {
        usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }

    /// Compact reading for the LCD trip line, like the photo's "173.5".
    static func lcdCompact(_ value: Int) -> String {
        switch value {
        case ..<1000: return String(value)
        case ..<1_000_000: return String(format: "%.1fk", Double(value) / 1000)
        default: return String(format: "%.2fM", Double(value) / 1_000_000)
        }
    }
}
