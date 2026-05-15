import SwiftUI
import UIKit

/// Cinematic OLED chrome: rounded display typography, small corner radii,
/// and accent gradient endpoints for wordmarks and primary actions.
/// Glass stays on nav/hero panels only — list rows use flat surfaces.
@available(iOS 17, *)
extension Theme {

    public enum Radius {
        /// Chips, inline controls, compact buttons.
        public static let sm: CGFloat = 6
        /// Deck panels, grouped field stacks.
        public static let md: CGFloat = 10
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

    /// Gradient start (electric blue) — tuned slightly brighter in dark mode.
    public static let cinematicAccentA = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? ThemeCinematicUIColor.hex(0x6AA8FF) : ThemeCinematicUIColor.hex(0x3D7CFF)
    })

    /// Gradient end (violet) — tuned for OLED legibility on dark backgrounds.
    public static let cinematicAccentB = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? ThemeCinematicUIColor.hex(0xE080FF) : ThemeCinematicUIColor.hex(0xC44CFF)
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
