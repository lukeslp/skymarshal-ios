import SwiftUI
import UIKit

/// Semantic color tokens. Light and dark variants are tuned so leading
/// stripes and chip backgrounds clear WCAG 1.4.11 non-text contrast
/// (≥3:1) against systemBackground in both schemes — a thing raw
/// `.red`, `.orange`, and especially `.yellow` cannot guarantee.
///
/// Resolution uses `UIColor(dynamicProvider:)` so Theme lives entirely
/// in this framework — no Assets.xcassets entries required, no
/// cross-target bundle lookup. Call sites use `Theme.danger`, etc.
@available(iOS 17, *)
public enum Theme {
    // Dark values track the Figma Make OLED palette (#FF3B30 / #FF9500 /
    // #30D158 / #FF375F / #3D7CFF) while light values stay WCAG-safe on
    // systemBackground (≥3:1 non-text).
    public static let danger  = dynamic(light: 0xC8312A, dark: 0xFF3B30)
    public static let caution = dynamic(light: 0xB36100, dark: 0xFF9500)
    public static let warn    = dynamic(light: 0x8A6500, dark: 0xFFD24E)
    public static let scope   = dynamic(light: 0x0066CC, dark: 0x3D7CFF)
    public static let success = dynamic(light: 0x1E7A30, dark: 0x30D158)
    public static let info    = dynamic(light: 0x1A6B99, dark: 0x5AC7FA)
    public static let like    = dynamic(light: 0xB83A66, dark: 0xFF375F)

    /// Tint for pill backgrounds. Replaces the previous `.opacity(0.10)`
    /// which fell to ~2.5:1 on yellow/orange. 0.18 alpha is the floor at
    /// which the underlying token still reads at ≥3:1 in light mode.
    public static func chipTint(_ base: Color) -> Color { base.opacity(0.18) }

    private static func dynamic(light: Int, dark: Int) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >>  8) & 0xFF) / 255.0,
            blue:  CGFloat( hex        & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
