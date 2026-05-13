# Skymarshal — iOS

Air-traffic control for your Bluesky.

Find old posts you forgot you wrote. Catch the late-night replies you'd rather not look at. Cull the followers you'd never have followed back. Skymarshal scans your own Bluesky archive, scores it, and lets you tidy in bulk — with the kind of confirmations a deletion deserves.

This is the iOS app. Native SwiftUI, iOS 17+. No third-party dependencies. App password only — Skymarshal never sees your real Bluesky password.

## Status

Pre-TestFlight v1.0.0, build 3. 145 XCTest unit cases pass (`-only-testing:SkymarshalTests`). Tagged `v1.0.1-pre-testflight` (most recent rollback anchor).

TestFlight Public Link goes here once the current build clears Beta App Review.

## What it does

**Content tab.** Search every post, reply, repost, and like in your archive. Filter by keyword, content type, date range, engagement count, alt-text, presence of media. Sort results (newest/oldest/highest or lowest engagement). Save named filter presets per account. Open **Insights** for on-device analytics (engagement distribution, posting hours/days, top words) — no analytics SDKs. Swipe-delete one at a time or Select All from a search result and delete a hundred at once. Bulk delete ≥ 100 items goes through a typed-confirm sheet so the intent is unambiguous.

**Followers tab.** Pull your full follow list and score every account against six bot signals plus inactivity and follower asymmetry. Sort, filter, segmented bot-sensitivity preset (Strict / Balanced / Loose). One-tap **cleanup presets** (inactive, automation signals, disengaged, follower skew). Optional **dry-run unfollow** previews unfollows (bulk confirmation and single-account sheet) with **no XRPC writes** when the toggle is on. Bulk unfollow uses the same rate-limit safety net as bulk delete. Per-account "this isn't an automated account" whitelist for false positives.

**Profile explorer.** From an account sheet, open read-only **followers** and **following** lists (paginated XRPC) — not a full Bluesky client timeline.

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

**Documentation map** (where to read first): [`docs/README.md`](docs/README.md).

Architecture overview (iOS layers, services, reference provenance): [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). SwiftUI UX guardrails for contributors: [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md). Upstream vs iOS feature scope (checklist): [`docs/UPSTREAM_FEATURE_GAP.md`](docs/UPSTREAM_FEATURE_GAP.md). Large-branch review / council synthesis: [`docs/TEAM_CONSENSUS_DECISION_PACKAGE.md`](docs/TEAM_CONSENSUS_DECISION_PACKAGE.md). Migration notes and Python-vs-TS drift rules: [`MIGRATION.md`](MIGRATION.md). Frozen upstream snapshot for parity: [`reference/README.md`](reference/README.md).

```
ios/
  SkymarshalCore/          # Framework — models, services, network, storage
    Models/                # AnalyzedAccount, ContentItem, Interaction, FollowerFilters
    Network/               # ATProtoClient, ATProtoTypes
    Services/              # ContentService, FollowerService, InteractionService, ProfileService, AnalyticsService
    Standards/             # Theme, ReduceMotion, BluescreenAnalyzer, Exporter, RateLimit, FeatureFlags
    Storage/               # SwiftData models (ContentItemRecord, AnalyzedAccountRecord, …)
  Skymarshal/              # App — SwiftUI views, AppModel
    UI/                    # 30+ SwiftUI views (ContentListView, BluescreenView, …)
    Assets.xcassets/       # AppIcon, LaunchBird, DotBird, EasterAlf, ColorSets
    Info.plist
    PrivacyInfo.xcprivacy
  SkymarshalTests/         # XCTest — 145 unit cases
  SkymarshalUITests/       # XCUITest — 2 AX5 regression cases
  project.yml              # xcodegen spec
docs/                      # README hub, ARCHITECTURE, CONTRIBUTOR_UX, GAP, review artifacts
reference/                 # frozen Python + TS lift — see reference/README.md
app-store/                 # paste-ready submission docs
```

## Public Release Pack

For public launch prep and App Store submission, use:

- `app-store/PUBLIC_RELEASE_PACK.md`
- `app-store/PUBLIC_RELEASE_COPY.md`
- `app-store/PUBLIC_RELEASE_ASSETS.md`
- `app-store/PUBLIC_RELEASE_RUNBOOK.md`

## License

MIT — © 2026 Luke Steuber.

## Contact

luke@lukesteuber.com · [lukesteuber.com](https://lukesteuber.com) · [@lukesteuber.com on Bluesky](https://bsky.app/profile/lukesteuber.com)

Skymarshal is not affiliated with Bluesky Social, PBC.
