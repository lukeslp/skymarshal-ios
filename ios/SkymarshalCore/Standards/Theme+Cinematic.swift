import SwiftUI
import UIKit

/// Cinematic OLED chrome from the Skymarshal Figma Make prototype:
/// void / elev surfaces, rounded display typography, small radii, and
/// blue→violet accent gradient. Glass stays on nav/hero panels only —
/// list rows use flat elev fills.
@available(iOS 17, *)
extension Theme {

    public enum Radius {
        /// Chips, inline controls, compact buttons (Make: 6).
        public static let sm: CGFloat = 6
        /// Deck panels, grouped field stacks (Make: 10).
        public static let md: CGFloat = 10
        /// Sheet / modal top corners (Make: 20).
        public static let lg: CGFloat = 20
    }

    public enum Display {
        public static func title(_ textStyle: Font.TextStyle = .largeTitle) -> Font {
            .system(textStyle, design: .rounded, weight: .bold)
        }

        /// Dense metrics and footer-scale chrome: system sans + tabular digits.
        public static func metric(_ textStyle: Font.TextStyle = .caption) -> Font {
            .system(textStyle, design: .default, weight: .medium).monospacedDigit()
        }

        public static func metricRegular(_ textStyle: Font.TextStyle = .caption) -> Font {
            .system(textStyle, design: .default, weight: .regular).monospacedDigit()
        }
    }

    // MARK: - Surface ladder (Figma Make OLED)

    /// Pure void / system background. Screen root chrome.
    public static let void = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x000000)
            : .systemBackground
    })

    /// First elevation — cards, decks (Make `#121218`).
    public static let elev1 = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x121218)
            : .secondarySystemBackground
    })

    /// Second elevation — inset fields, nested panels (Make `#1A1A26`).
    public static let elev2 = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x1A1A26)
            : .tertiarySystemBackground
    })

    /// Third elevation — pressed / elevated chips (Make `#222230`).
    public static let elev3 = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x222230)
            : .quaternarySystemFill
    })

    /// Hairline border on elev surfaces (Make `rgba(255,255,255,0.08)`).
    public static let hairline = Color.primary.opacity(0.08)

    /// Medium hairline for focus / modal edges (Make `0.13`).
    public static let hairlineMed = Color.primary.opacity(0.13)

    /// Gradient start (electric blue) — Make `#3D7CFF`; slightly brighter in dark for OLED.
    public static let cinematicAccentA = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x3D7CFF)
            : ThemeCinematicUIColor.hex(0x3D7CFF)
    })

    /// Gradient end (violet) — Make `#C44CFF`.
    public static let cinematicAccentB = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0xC44CFF)
            : ThemeCinematicUIColor.hex(0xC44CFF)
    })

    public static var cinematicTitleGradient: LinearGradient {
        LinearGradient(
            colors: [cinematicAccentA, cinematicAccentB],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Solid title fallback when gradient / color differentiation would fail review.
    public static let cinematicTitleSolid = Theme.scope

    /// Login / root OLED terminus — Make void black with a hair of indigo depth.
    public static let cinematicPageBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? ThemeCinematicUIColor.hex(0x000000)
            : .systemBackground
    })
}

@available(iOS 17, *)
public extension View {
    /// Applies void list chrome used across Content / Patterns / Scope / About.
    func cinematicListChrome() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.void.ignoresSafeArea())
    }

    /// Flat elev strip behind inline banners / chip rows (not `.thinMaterial`).
    func cinematicChromeStrip() -> some View {
        self
            .background(Theme.elev1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Theme.hairline)
                    .frame(height: 1)
            }
    }

    /// Make list language: hairline separators on void, no system gray rules.
    func cinematicListRows() -> some View {
        self
            .listRowSeparatorTint(Theme.hairline)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    /// Sheet presentation corners matching Make modal radius (20).
    func cinematicSheetChrome() -> some View {
        self.presentationCornerRadius(Theme.Radius.lg)
    }
}

@available(iOS 17, *)
extension Theme {
    /// List-row fill matching Make Content/Patterns: void idle, accent wash when selected.
    public static func cinematicRowFill(selected: Bool) -> Color {
        selected ? cinematicAccentA.opacity(0.10) : Color.clear
    }
}

private enum ThemeCinematicUIColor {
    static func hex(_ value: Int) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
