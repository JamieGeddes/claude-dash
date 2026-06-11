import SwiftUI

/// Palette and typography for the 992 GT3 cluster: near-black faces, white
/// numerals, yellow needles, Guards Red accents.
enum GT3Theme {
    static let face = Color(red: 0.035, green: 0.035, blue: 0.042)
    static let faceEdge = Color(red: 0.10, green: 0.10, blue: 0.115)
    static let housing = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let bezel = Color(white: 0.22)
    static let tick = Color(white: 0.92)
    static let numeral = Color(white: 0.95)
    static let caption = Color(white: 0.55)
    static let lcd = Color(white: 0.88)
    static let red = Color(red: 0.84, green: 0.0, blue: 0.11)        // Porsche Guards Red
    static let needle = Color(red: 1.0, green: 0.82, blue: 0.10)     // GT3 yellow
    static let badgeYellow = Color(red: 1.0, green: 0.85, blue: 0.25)
    static let staleAmber = Color(red: 1.0, green: 0.7, blue: 0.1)

    /// Porsche's cluster typeface is proprietary; prefer it when locally
    /// installed, otherwise use the bundled Saira SemiCondensed lookalike.
    static func dial(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let candidates: [String]
        switch weight {
        case .semibold, .bold:
            candidates = ["PorscheNext-Bold", "Porsche Next Bold", "SairaSemiCondensed-SemiBold"]
        case .regular, .light:
            candidates = ["PorscheNext-Regular", "Porsche Next", "SairaSemiCondensed-Regular"]
        default:
            candidates = ["PorscheNext-Regular", "Porsche Next", "SairaSemiCondensed-Medium"]
        }
        return FontLoader.font(candidates: candidates, size: size, weight: weight)
    }

    static func currency(_ usd: Double) -> String {
        usd >= 100 ? String(format: "$%.0f", usd) : String(format: "$%.2f", usd)
    }

    static func formatted(_ value: Int) -> String {
        Self.groupingFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{2009}" // thin space, like cluster displays
        return f
    }()
}
