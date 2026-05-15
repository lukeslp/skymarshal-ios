// ThemeFontRegistrationTests.swift
//
// RELEASE-safe verification that the bundled IBM Plex Mono OTFs
// register correctly. Wired into the standard `xcodebuild test` run so
// a Plex Mono PostScript-vs-filename mismatch (or a missing
// `UIAppFonts` entry, or a Copy Bundle Resources phase drop) fails CI
// before any archive build can hit TestFlight.
//
// Greybeard's ship-blocker for v1.0.1: the `Theme.audit()` precondition
// in `Theme+Fonts.swift` is DEBUG-only by design — production failures
// fall back to `Font.system(.monospaced)` silently. The XCTest path
// here is the build-time tripwire that closes the silent-fallback gap.
//
// Inputs:   the host app's `UIAppFonts` registration (test bundle is
//           hosted by `Skymarshal.app`, so the fonts in
//           `ios/Skymarshal/Resources/Fonts/` are loaded at test launch).
// Outputs:  XCTest pass when every face resolves; fail with a precise
//           diagnostic listing every missing face on regression.

import XCTest
@testable import SkymarshalCore

@available(iOS 17, *)
final class ThemeFontRegistrationTests: XCTestCase {

    func test_bundledPlexMonoFaces_registerSuccessfully() {
        let missing = Theme.verifyFontsRegistered()
        XCTAssertTrue(
            missing.isEmpty,
            "Plex Mono face(s) failed to resolve at runtime — Theme.Mono.* will silently fall back to the system monospaced face. Missing:\n" + missing.joined(separator: "\n")
        )
    }
}
