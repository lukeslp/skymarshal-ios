import SwiftUI
import SkymarshalCore

/// Visual encoding for the four real content types. The Things 3 / Notion
/// pattern: a thin leading hairline gives the eye a category cue while
/// scanning a long list, without the saturation noise of a colored row.
/// Stripe colors come from `Theme` so they hit WCAG 1.4.11 ≥3:1 contrast
/// in both light and dark mode.
@available(iOS 17, *)
extension ContentType {
    var stripeColor: Color {
        switch self {
        case .all:     return .secondary
        case .posts:   return Theme.scope
        case .replies: return Theme.info
        case .reposts: return Theme.success
        case .likes:   return Theme.like
        }
    }

    var sfSymbol: String {
        switch self {
        case .all:     return "square.stack.3d.up"
        case .posts:   return "text.alignleft"
        case .replies: return "bubble.left.and.text.bubble.right"
        case .reposts: return "arrow.2.squarepath"
        case .likes:   return "heart.fill"
        }
    }
}
