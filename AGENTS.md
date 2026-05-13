# Repository Guidelines

## Project Structure & Module Organization

Skymarshal is a native SwiftUI iOS app targeting iOS 17+. The active app lives in `ios/`; `reference/` contains prior Python and web implementations, and `app-store/` contains submission copy.

For what the upstream Python/web/npm stacks include versus this native surface (scope map, not a port backlog), see [`docs/UPSTREAM_FEATURE_GAP.md`](docs/UPSTREAM_FEATURE_GAP.md).

**Documentation hub** (architecture, UX guardrails, review artifacts): [`docs/README.md`](docs/README.md).

Inside `ios/`, `project.yml` is the canonical XcodeGen spec. Do not hand-edit `Skymarshal.xcodeproj` when target settings can be changed in `project.yml`. `SkymarshalCore/` is the framework for models, networking, services, storage, and standards. `Skymarshal/` contains the SwiftUI app, assets, privacy manifest, entitlements, and UI state. Tests are split between `SkymarshalTests/` for XCTest unit coverage and `SkymarshalUITests/` for XCUITest accessibility regressions.

## Build, Test, and Development Commands

Run commands from `ios/` unless noted:

```bash
xcodegen generate --spec project.yml
xcrun simctl boot "iPhone 17"
xcodebuild test -scheme Skymarshal -destination 'platform=iOS Simulator,name=iPhone 17'
```

`xcodegen generate` refreshes the Xcode project from the spec. `xcodebuild test` builds the app, framework, unit tests, and UI tests. Use Xcode 26.4+ with an iOS 17 SDK or later.

## Coding Style & Naming Conventions

Use Swift 5.9 conventions: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and functions, and descriptive XCTest names such as `testStorageRoundTripPreservesContentType`. Keep shared behavior in `SkymarshalCore`.

Follow existing standards helpers. Use `Theme` colors instead of raw status colors, `ReduceMotion.shouldReduce(...)` for animations, and `RateLimit.withBackoff` for retry behavior. Preserve app-password language and avoid “AI” marketing copy. For new SwiftUI surfaces, follow [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md) so layout, menus, and destructive semantics stay consistent with shipped patterns.

For content records, keep display identity separate from destructive identity. `ContentItem.uri` is the subject being shown; `ContentItem.deletionURI` is the AT Protocol record to delete. Likes and reposts must use the viewer record URI, not the subject post URI.

## Testing Guidelines

Tests use XCTest and XCUITest. Add focused unit tests in `ios/SkymarshalTests/` for model, service, storage, scoring, filtering, and rate-limit behavior. Add UI regression tests in `ios/SkymarshalUITests/` for accessibility, Dynamic Type, or destructive-flow changes. Prefer `UITestBootstrap.swift` launch keys over ad hoc strings; see [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md) “UI testing (XCUITest)”. Run the full `xcodebuild test` command before opening a PR when behavior changes.

## Commit & Pull Request Guidelines

Recent history uses short, prefixed commit subjects such as `feat: ...`, `fix: ...`, `docs: ...`, `release: ...`, and `xcscheme: ...`. Keep subjects imperative and specific, with scope in the prefix when useful.

Pull requests should include a concise summary, test results, and screenshots or recordings for visible UI changes. Link related issues when applicable. Call out changes to privacy, Keychain/session handling, destructive actions, rate limits, or App Store copy.

## Security & Configuration Tips

Never persist Bluesky passwords; use app passwords and Keychain-backed session storage. Keep network access limited to Bluesky XRPC endpoints unless a change explicitly requires otherwise. `PrivacyInfo.xcprivacy` must stay aligned with actual data collection behavior.
