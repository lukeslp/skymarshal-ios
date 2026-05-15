// TokenCoverageTests.swift
//
// Tripwire that fails the build if any raw `.red` / `.orange` / `.yellow`
// color literal leaks into the codebase outside `Theme*.swift`. Those
// raw colors don't satisfy WCAG 1.4.11 in both light AND dark — the
// `Theme.danger / .caution / .warn` tokens (and only the tokens) carry
// the dual-mode contrast tuning. Re-introducing a raw literal silently
// regresses the contrast story.
//
// Inputs:   Filesystem walks of `ios/Skymarshal/**.swift` and
//           `ios/SkymarshalCore/**.swift`.
// Outputs:  XCTest pass/fail. Failures list the offending file + line.

import XCTest

@available(iOS 17, *)
final class TokenCoverageTests: XCTestCase {

    /// Raw color literals are banned outside `Theme*.swift`. The regex
    /// uses negative lookarounds so we don't trip on `.reduce`,
    /// `.reduceMotion`, etc.
    func test_noRawStatusColorsOutsideTheme() throws {
        let pattern = #"(?<!\w)(\.red|\.orange|\.yellow|Color\.red|Color\.orange|Color\.yellow)(?!\w)"#
        let regex = try NSRegularExpression(pattern: pattern)

        let iosRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // SkymarshalTests/
            .deletingLastPathComponent()    // ios/

        let scanRoots = [
            iosRoot.appendingPathComponent("Skymarshal"),
            iosRoot.appendingPathComponent("SkymarshalCore"),
        ]
        let allowedFiles: Set<String> = [
            "Theme.swift",
            "Theme+Fonts.swift",
            "Theme+Cinematic.swift",
            "Theme+Saturn.swift",
        ]

        var offenders: [String] = []
        let fm = FileManager.default
        for root in scanRoots {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                guard !allowedFiles.contains(url.lastPathComponent) else { continue }
                guard let body = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let range = NSRange(body.startIndex..., in: body)
                regex.enumerateMatches(in: body, range: range) { match, _, _ in
                    guard let match, let r = Range(match.range, in: body) else { return }
                    let line = body[..<r.lowerBound].filter { $0 == "\n" }.count + 1
                    offenders.append("\(url.path):\(line) — \(body[r])")
                }
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            "Raw status color literals found outside Theme*.swift:\n" + offenders.joined(separator: "\n")
        )
    }
}
