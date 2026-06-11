import SwiftUI
import CoreText
import AppKit

enum FontLoader {
    /// Registers every bundled font for this process. Called once at launch so
    /// both `swift run` and the .app bundle get the dial typefaces.
    static func registerBundledFonts() {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else {
            return
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// First available font from `candidates` (PostScript names), falling back
    /// to the system font. Lets a design prefer a locally-installed face
    /// (e.g. Porsche Next) over its bundled lookalike.
    static func font(candidates: [String], size: CGFloat, weight: Font.Weight = .regular) -> Font {
        for name in candidates where NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
    }
}
