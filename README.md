# Skymarshal — iOS

Air-traffic control for your Bluesky.

Find old posts you forgot you wrote. Catch the late-night replies you'd rather not look at. Cull the followers you'd never have followed back. Skymarshal scans your own Bluesky archive, scores it, and lets you tidy in bulk — with the kind of confirmations a deletion deserves.

This is the iOS app. Native SwiftUI, iOS 17+. No third-party dependencies. App password only — Skymarshal never sees your real Bluesky password.

## Status

Pre-TestFlight v1.0.0, build 3. 137 tests pass. Tagged `v1.0.1-pre-testflight` (most recent rollback anchor).

TestFlight Public Link goes here once the current build clears Beta App Review.

## What it does

**Content tab.** Search every post, reply, repost, and like in your archive. Filter by keyword, content type, date range, engagement count, alt-text, presence of media. Swipe-delete one at a time or Select All from a search result and delete a hundred at once. Bulk delete ≥ 100 items goes through a typed-confirm sheet so the intent is unambiguous.

**Followers tab.** Pull your full follow list and score every account against six bot signals plus inactivity and follower asymmetry. Sort, filter, segmented bot-sensitivity preset (Strict / Balanced / Loose). Bulk unfollow with the same rate-limit safety net the bulk delete uses. Per-account "this isn't an automated account" whitelist for false positives.

**Interactions history.** Tap any account to see every interaction between you and them in either direction. Default cap 200 items per direction; toggle Deep Sweep in the sheet to widen to 2,000.

## Privacy

Data Not Collected. Your handle, posts, and follows stay on this device. The only server Skymarshal talks to is Bluesky itself (`bsky.social` and `public.api.bsky.app`) — no analytics, no third-party SDKs, no telemetry.

App password is held in iOS Keychain on your device. Bluesky communications go directly from your device to Bluesky's public XRPC endpoints.

## Accessibility

Pre-TestFlight v1.0 floor: WCAG 1.4.11 color contrast in both light and dark mode; Reduce Motion respected at every animation site (plus an in-app override); Dynamic Type to AX5 without truncation on primary views; VoiceOver labels on every interactive element; Switch Control reach via `.accessibilityAction(named:)` on every destructive row action; live-region announcements for silent state changes (selection prune, sign-in error). One XCUITest at AX5 catches Dynamic Type regressions.

## Build

```bash
cd ios
xcodegen generate --spec project.yml
xcrun simctl boot "iPhone 17"
xcodebuild test -scheme Skymarshal -destination 'platform=iOS Simulator,name=iPhone 17'
```

Requires Xcode 26.4+, iOS 17 SDK or later.

## Implementation notes

Content rows distinguish between the subject URI being displayed and the record URI used for destructive actions. Posts and replies delete their own post records; likes and reposts delete the viewer's like/repost record (`viewer.like` / `viewer.repost`) while still showing the subject post. Cached content is scoped by owner, content type, and subject URI to avoid cross-account collisions.

## Repo layout

```
ios/
  SkymarshalCore/          # Framework — models, services, network, storage
    Models/                # AnalyzedAccount, ContentItem, Interaction, FollowerFilters
    Network/               # ATProtoClient, ATProtoTypes
    Services/              # ContentService, FollowerService, InteractionService
    Standards/             # Theme, ReduceMotion, BluescreenAnalyzer, Exporter, RateLimit
    Storage/               # SwiftData models (ContentItemRecord, AnalyzedAccountRecord, …)
  Skymarshal/              # App — SwiftUI views, AppModel
    UI/                    # 30+ SwiftUI views (ContentListView, BluescreenView, …)
    Assets.xcassets/       # AppIcon, LaunchBird, DotBird, EasterAlf, ColorSets
    Info.plist
    PrivacyInfo.xcprivacy
  SkymarshalTests/         # XCTest — 133 unit cases
  SkymarshalUITests/       # XCUITest — 2 AX5 regression cases
  project.yml              # xcodegen spec
app-store/                 # paste-ready submission docs
```

## License

MIT — © 2026 Luke Steuber.

## Contact

luke@lukesteuber.com · [lukesteuber.com](https://lukesteuber.com) · [@lukesteuber.com on Bluesky](https://bsky.app/profile/lukesteuber.com)

Skymarshal is not affiliated with Bluesky Social, PBC.
