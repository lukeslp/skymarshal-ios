# Skymarshal — iOS

Air-traffic control for your Bluesky.

Find old posts you forgot you wrote. Catch the late-night replies you'd rather not look at. Cull the followers you'd never have followed back. Skymarshal scans your own Bluesky archive, scores it, and lets you tidy in bulk, with confirmations that match the stakes.

This is the iOS app. Native SwiftUI, iOS 17+. No third-party dependencies. App password only — Skymarshal never sees your real Bluesky password.

## Status

Public TestFlight v1.0.0, build 5. The native reference app now also carries the Figma Make parity surface: cinematic OLED chrome, first-run onboarding, structured Advanced Search, expandable Patterns rows, and local-cache Scope graphs. **272** unit tests in `SkymarshalTests` passed at the latest full-suite checkpoint.

A short-lived `v1.0.1` working label was retired in May 2026. Nothing shipped under it; the scope folded back into the in-progress 1.0.0.

TestFlight Public Link in [`docs/TESTFLIGHT_PUBLIC_LINK.md`](docs/TESTFLIGHT_PUBLIC_LINK.md). App Store submission is gated by the pre-ship checklist in [`PROJECT_PLAN.md`](PROJECT_PLAN.md): a resumable-delete breadcrumb fix, a USPTO TESS check on the name, a "Patterns" rename for the Followers tab heading, and a reviewer-notes file citing `com.atproto.repo.deleteRecord` as a documented public AT Protocol lexicon.

## What it does

**Content tab.** Search every post, reply, repost, and like in your archive. Advanced Search provides required terms, excluded terms, exact phrases, content types, dates, and a live estimate against the loaded archive; media, engagement, alt-text, subject, and DID filters remain available under More filters. Sort results (newest/oldest/highest or lowest engagement). Save named filter presets per account. Open **Insights** for on-device analytics (engagement distribution, posting hours/days, top words) plus optional **word-pattern stats** (lexicon hits; not sentiment) behind `sm.feature.wordPatterns`. Swipe-delete one at a time or Select All from a search result and delete a hundred at once. Bulk delete shows a **preflight scope** (how many Bluesky records will actually delete vs. skipped selections). Bulk delete ≥ 100 items goes through a typed-confirm sheet so the intent is unambiguous.

**Scope tab.** Local-cache Account Graph, Post Graph, attributed interaction timeline, and posting heatmap. Every relationship comes from cached content or scanned accounts; missing relationships are labeled rather than synthesized. Scope is default-on via `sm.feature.visualizationHub`.

**About → Backup & restore (optional).** Import Skymarshal JSON exports with handle/DID checks and merge-or-replace apply — gated by `sm.feature.backupRestore` (default off).

**Patterns tab.** Pull your full follow list and score every account against six automation signals plus inactivity and follower asymmetry. Inline score tracks and expandable evidence keep the reasoning visible without forcing a detail sheet. Sort, filter, and choose a Strict / Balanced / Loose sensitivity preset. One-tap **cleanup presets** cover inactivity, automation signals, disengagement, and follower skew. Optional **dry-run unfollow** previews unfollows with **no XRPC writes** when the toggle is on. Bulk unfollow uses the same rate-limit safety net as bulk delete. Per-account whitelisting handles false positives.

**Profile explorer.** From an account sheet, open read-only **followers** and **following** lists (paginated XRPC) — not a full Bluesky client timeline.

**Interactions history.** Tap any account to see every interaction between you and them in either direction. Default cap 200 items per direction; toggle Deep Sweep in the sheet to widen to 2,000.

## Privacy

Data Not Collected. Your handle, posts, and follows stay on this device. The only server Skymarshal talks to is Bluesky itself (`bsky.social` and `public.api.bsky.app`) — no analytics, no third-party SDKs, no telemetry.

Your app password is **never persisted** — it's used once to obtain an AT Protocol session and then discarded. The rotating session tokens (`accessJwt` + `refreshJwt`) issued by Bluesky are stored in the iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no iCloud sync). When the access token expires the app refreshes it transparently against `com.atproto.server.refreshSession`; only an expired or revoked refresh token returns you to the sign-in screen. Bluesky communications go directly from your device to Bluesky's public XRPC endpoints.

## Accessibility

v1.0 floor: WCAG 1.4.11 color contrast in both light and dark mode; Reduce Motion respected at every animation site (plus an in-app override); Dynamic Type to AX5 without truncation on primary views; VoiceOver labels on every interactive element; Switch Control reach via `.accessibilityAction(named:)` on every destructive row action; live-region announcements for silent state changes (selection prune, sign-in error). One XCUITest at AX5 catches Dynamic Type regressions.

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

Architecture overview (iOS layers, services, reference provenance): [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). SwiftUI UX guardrails for contributors: [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md). Upstream vs iOS feature scope (checklist): [`docs/UPSTREAM_FEATURE_GAP.md`](docs/UPSTREAM_FEATURE_GAP.md). Parity + visualization execution roadmap: [`docs/PARITY_VISUALIZATION_PLAN.md`](docs/PARITY_VISUALIZATION_PLAN.md). Expansion UX and design specs: [`docs/UX_SPEC.md`](docs/UX_SPEC.md), [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md). Large-branch review synthesis: [`docs/TEAM_CONSENSUS_DECISION_PACKAGE.md`](docs/TEAM_CONSENSUS_DECISION_PACKAGE.md). Migration notes and Python-vs-TS drift rules: [`MIGRATION.md`](MIGRATION.md). Frozen upstream snapshot for parity: [`reference/README.md`](reference/README.md).

```
ios/
  SkymarshalCore/          # Framework — models, services, network, storage
    Models/                # AnalyzedAccount, ContentItem, Interaction, FollowerFilters
    Network/               # ATProtoClient (refresh-and-retry, Keychain-backed sessions), ATProtoTypes
    Services/              # ContentService, FollowerService, InteractionService, ProfileService, AnalyticsService, DeletePreflight, WordPatternsService, ContentBackupImport, GraphSnapshotWriter, …
    Standards/             # Theme, ReduceMotion, BluescreenAnalyzer, Exporter, RateLimit, FeatureFlags, SessionStore
    Storage/               # SwiftData models (ContentItemRecord, AnalyzedAccountRecord, …)
  Skymarshal/              # App — SwiftUI views, AppModel
    UI/                    # 30+ SwiftUI views (ContentListView, BluescreenView, …)
    Assets.xcassets/       # AppIcon, LaunchBird, DotBird, EasterAlf, ColorSets
    Info.plist
    PrivacyInfo.xcprivacy
  SkymarshalTests/         # XCTest — 272 passing unit tests at latest checkpoint
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
