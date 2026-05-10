import SwiftUI
import SkymarshalCore

/// Visual encoding for the four real content types. The Things 3 / Notion
/// pattern: a thin leading hairline gives the eye a category cue while
/// scanning a long list, without the saturation noise of a colored row.
@available(iOS 17, *)
extension ContentType {
    var stripeColor: Color {
        switch self {
        case .all:     return .secondary
        case .posts:   return .accentColor                // Bluesky blue — the canonical "post"
        case .replies: return Color(red: 0.35, green: 0.78, blue: 0.98)  // soft cyan
        case .reposts: return Color(red: 0.20, green: 0.78, blue: 0.35)  // muted leaf green
        case .likes:   return Color(red: 0.95, green: 0.30, blue: 0.55)  // dusty rose
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
