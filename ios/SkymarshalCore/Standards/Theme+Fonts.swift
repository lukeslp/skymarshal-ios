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

    #if DEBUG
    /// Crash early if a bundled font family failed to register. Wire from
    /// the app's `init` behind `#if DEBUG`. Release builds skip this so a
    /// freshly-installed app doesn't crash on someone's iPhone because of
    /// a font shipping miss — production failures fall back to the system
    /// monospaced face and surface in TestFlight screenshots before they
    /// hit the store.
    public static func audit() {
        let expected: [String: [String]] = [
            "IBM Plex Mono": [
                "IBMPlexMono",
                "IBMPlexMono-Medm", "IBMPlexMono-Medium",
                "IBMPlexMono-SmBld", "IBMPlexMono-SemiBold",
            ],
        ]
        for (family, candidates) in expected {
            let resolved = Set(UIFont.fontNames(forFamilyName: family))
            let missing = candidates.filter { !resolved.contains($0) }
            // Every family must resolve at least one of each face's
            // candidate spellings — the Mono.psNames map above pairs
            // canonical name first, fallback second. If neither is
            // present, the bundle is broken.
            let coverage: [Bool] = [
                resolved.contains("IBMPlexMono"),
                resolved.contains("IBMPlexMono-Medm") || resolved.contains("IBMPlexMono-Medium"),
                resolved.contains("IBMPlexMono-SmBld") || resolved.contains("IBMPlexMono-SemiBold"),
            ]
            precondition(
                coverage.allSatisfy({ $0 }),
                "Theme.audit: \(family) coverage failed. Resolved: \(resolved). Missing candidates from expected list: \(missing)."
            )
        }
    }
    #endif
}
