import SwiftUI
import SkymarshalCore

/// Build an AttributedString from a Bluesky post's text + facets so
/// URLs render as tappable links inline. Bluesky's facets carry
/// **UTF-8 byte ranges** (not UTF-16 character offsets), which is
/// what bites you if you try to use the offsets directly with
/// String.Index. This helper does the conversion.
@available(iOS 17, *)
enum AttributedPostText {

    /// Returns an AttributedString with `.link` + accent-color marks
    /// for every facet range whose UTF-8 byte offsets resolve to a
    /// valid String.Index range. Out-of-bounds or non-character-boundary
    /// facets are silently skipped — Bluesky has occasional malformed
    /// facets in the wild and they shouldn't break the whole render.
    static func make(text: String, links: [TextLink]) -> AttributedString {
        var attr = AttributedString(text)
        guard !links.isEmpty else { return attr }

        let utf8 = text.utf8
        for link in links {
            guard
                link.byteStart >= 0,
                link.byteEnd >= link.byteStart,
                link.byteEnd <= utf8.count,
                let startUtf8 = utf8.index(utf8.startIndex, offsetBy: link.byteStart, limitedBy: utf8.endIndex),
                let endUtf8 = utf8.index(utf8.startIndex, offsetBy: link.byteEnd, limitedBy: utf8.endIndex),
                let startStr = startUtf8.samePosition(in: text),
                let endStr = endUtf8.samePosition(in: text),
                startStr <= endStr,
                let attrRange = Range(startStr..<endStr, in: attr)
            else { continue }

            attr[attrRange].link = link.url
            attr[attrRange].foregroundColor = .accentColor
            attr[attrRange].underlineStyle = .single
        }
        return attr
    }
}
