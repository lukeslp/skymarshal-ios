> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../../README.md).

//
//  WidgetSupport.swift
//  Skymarshal
//
//  Created July 2026
//

import SwiftUI

// MARK: - Widget Font & Style Configuration

extension Font {
    /// The primary font used throughout all Skymarshal widgets.
    /// Uses Open Sans if available; otherwise falls back to the system's rounded font.
    static var skymarshalWidgetFont: Font {
        if UIFont.familyNames.contains("Open Sans") {
            return .custom("Open Sans", size: 14, relativeTo: .body)
        } else {
            return .system(.body, design: .rounded)
        }
    }
}

extension Text {
    /// Applies the standard widget font style.
    func skymarshalWidgetStyle() -> Text {
        self.font(.skymarshalWidgetFont)
            .foregroundColor(.primary)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
    }
}

struct SkymarshalWidgetStyle {
    /// A shared color palette emphasizing warmth and readability.
    static let primaryTextColor = Color.primary
    static let secondaryTextColor = Color.secondary
    static let positiveIndicatorColor = Color.green
    static let negativeIndicatorColor = Color.red
    static let neutralIndicatorColor = Color.gray
    
    /// Standard padding for widget elements
    static let standardPadding: CGFloat = 8
    
    /// Corner radius for widget components
    static let cornerRadius: CGFloat = 10
}

// End of WidgetSupport.swift
