// Theme+Fonts.swift
//
// Typography tokens. Wraps `Font.custom(...)` with a fallback chain so a
// missing font in RELEASE degrades to the system monospaced face instead
// of a silent SF Pro substitution. The `Theme.audit()` precondition is
// the DEBUG safety net: it crashes at app startup if any expected
// PostScript family + face combination is missing, which is the only
// reliable way to catch "I forgot to add the OTF to Copy Bundle
// Resources" before TestFlight.
//
// Inputs:   none (reads bundled UIFont names at runtime).
// Outputs:  `Theme.Mono.{kicker, body, tabular, caption}` SwiftUI fonts.
//
// IBM Plex 6.0+ abbreviated the Medium / SemiBold PostScript names to
// `-Medm` / `-SmBld`. The current bundled Plex Mono 1.1.0 uses the
// abbreviated forms; the audit accepts either spelling so a future
// re-release that restores the long names won't break us.

import SwiftUI
import UIKit

@available(iOS 17, *)
extension Theme {

    public enum Mono {

        public static func kicker(_ size: CGFloat = 11) -> Font {
            resolve(face: .semibold, size: size, relativeTo: .caption2)
        }

        public static func body(_ size: CGFloat = 13) -> Font {
            resolve(face: .regular, size: size, relativeTo: .caption)
        }

        public static func tabular(_ size: CGFloat = 13) -> Font {
            resolve(face: .medium, size: size, relativeTo: .caption)
                .monospacedDigit()
        }

        public static func caption(_ size: CGFloat = 11) -> Font {
            resolve(face: .regular, size: size, relativeTo: .caption2)
        }

        // MARK: - Internals

        fileprivate enum Face { case regular, medium, semibold }

        private static func resolve(face: Face, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
            for candidate in psNames(for: face) {
                if UIFont(name: candidate, size: size) != nil {
                    return Font.custom(candidate, size: size, relativeTo: style)
                }
            }
            return Font.system(style, design: .monospaced)
        }

        fileprivate static func psNames(for face: Face) -> [String] {
            switch face {
            case .regular:  return ["IBMPlexMono"]
            case .medium:   return ["IBMPlexMono-Medm", "IBMPlexMono-Medium"]
            case .semibold: return ["IBMPlexMono-SmBld", "IBMPlexMono-SemiBold"]
            }
        }
    }

    /// Returns a list of human-readable strings describing every face
    /// Skymarshal expects to resolve at runtime that did NOT resolve
    /// against the bundled `UIAppFonts`. Empty array = all good.
    ///
    /// Build-time verification path. Called from `xcodebuild test` via
    /// `ThemeFontRegistrationTests` so a Plex Mono PostScript-vs-filename
    /// mismatch fails CI **before** archive instead of silently falling
    /// back to `Font.system(.monospaced)` in production.
    ///
    /// Greybeard's ship-blocker for v1.0.1: this exists because the
    /// DEBUG-only `audit()` precondition can't catch a font registration
    /// regression on the archive build that actually goes to TestFlight.
    public static func verifyFontsRegistered() -> [String] {
        var missing: [String] = []

        let faces: [(label: String, candidates: [String])] = [
            ("IBM Plex Mono Regular",  ["IBMPlexMono"]),
            ("IBM Plex Mono Medium",   ["IBMPlexMono-Medm",  "IBMPlexMono-Medium"]),
            ("IBM Plex Mono SemiBold", ["IBMPlexMono-SmBld", "IBMPlexMono-SemiBold"]),
        ]
        let resolved = Set(UIFont.fontNames(forFamilyName: "IBM Plex Mono"))
        for face in faces where !face.candidates.contains(where: resolved.contains) {
            missing.append("\(face.label) (expected one of \(face.candidates), resolved: \(resolved))")
        }
        return missing
    }

    #if DEBUG
    /// Crash early if a bundled font family failed to register. Wire from
    /// the app's `init` behind `#if DEBUG`. Release builds skip this so a
    /// freshly-installed app doesn't crash on someone's iPhone because of
    /// a font shipping miss — production failures fall back to the system
    /// monospaced face. The RELEASE-safe verification path is
    /// `verifyFontsRegistered()` above, wired into `xcodebuild test`.
    public static func audit() {
        let missing = verifyFontsRegistered()
        precondition(missing.isEmpty, "Theme.audit failed: \(missing.joined(separator: " | "))")
    }
    #endif
}
