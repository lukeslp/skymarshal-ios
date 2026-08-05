# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project intent

**Direction changed 2026-06-21 toward "Option B" (Capacitor web-wrapper).** That
prototype lives in a **separate repo** —
`~/workspace/skymarshal-web`, branch `feature/ios-capacitor-wrapper` — and is
**validated end-to-end**: the client builds to a static bundle, wraps via
Capacitor 8.4.1 (SPM), and runs natively on iOS under bundle id
`blue.skymarshal.ios`. Full plan + status: `~/workspace/skymarshal-web/CAPACITOR_WRAPPER.md`.

Native development resumed in July for Figma Make parity and release hardening.
**The native app is live in the App Store** at **1.0.3** — confirmed against ASC
2026-08-05. This file previously claimed 1.0.2 / build 40, which was stale; git
history alone cannot tell you what actually shipped, so **query ASC before
believing any version claim here** (`fastlane asc_state`). 1.0.4 was opened as a
version record but never submitted, and its record was renamed to 1.1.0.

Current native source is **1.1.0 / build 52**, submitted 2026-08-05 and
`WAITING_FOR_REVIEW` with build 52 attached. Because 1.0.3 is live, the only
user-visible changes in 1.1 are ghost likes, word patterns on by default, and the
removal of a dead settings toggle; the 1.1 release notes also re-list Guided Mode,
the VoiceOver pass, and the icon, which 1.0.3 users already have.
The Capacitor path remains a
proposed alternative only. This repo also remains the source for:
- the **safety-critical deletion engine** in `SkymarshalCore` (the sacred 429
  ladder, resumable breadcrumb, preflight, typed-confirm) — prototyped for the
  Capacitor app as a native plugin (`SkymarshalDeletePlugin.swift`); keep it as the
  canonical reference;
- behavior parity, copy/brand voice, and the Bluescreen scoring logic.

Scope is unchanged — **content management**: authenticate, search the user's own
posts / replies / reposts / likes with dynamic filters, delete them safely, plus
the Bluescreen follower-scan surface. Firehose, network graphs, sentiment,
analytics dashboards, egonet remain **out of scope** unless explicitly requested.

Note: `CLAUDE.md` is checked in — keep it concise and current. If you want a private scratch file, use `CLAUDE.local.md` (gitignored by convention) instead.

## What lives here today

```
ios/                          # Active native SwiftUI source — version 1.1.0, build 52 (App Store live: 1.0.3).
  project.yml                 # xcodegen canonical source — never edit .xcodeproj directly
  Skymarshal/                 # App target: SwiftUI views, AppModel, App entry
  SkymarshalCore/             # Framework: Models, Services, Standards, Network, Storage
  SkymarshalTests/            # 326 unit tests; verified green 2026-08-05
                              #   (ScreenshotTest needs SKY_TEST_HANDLE/_APP_PASSWORD;
                              #   -skip-testing:SkymarshalUITests/ScreenshotTest in dev runs)
  SkymarshalUITests/          # UI harness with sm.feature.* flag bridge
docs/                         # iOS-specific planning + design artifacts
  PROJECT_PLAN.md             # (mirror at repo root) — distribution status, council log
  PARITY_VISUALIZATION_PLAN.md, STYLE_RESTYLE_PLAN.md, UPSTREAM_FEATURE_GAP.md
  ARCHITECTURE.md, DESIGN_SYSTEM.md, CONTRIBUTOR_UX.md
  aesthetic-samples/, archive/
app-store/                    # Release pack — screenshots, listing copy, reviewer notes
reference/                    # NOT runnable — anchors parity, ports, and pitch decisions
  python/                     # Python CLI snapshot (auth.py, deletion.py, search.py,
                              #   engagement_cache.py, models.py, services/content_service.py)
                              # — the canonical engagement weights + 429 ladder live here
  web/                        # React/TS client snapshot (skymarshal.blue) —
                              #   pages/{Login,Search,ContentManagement,DataManagement,Cleanup}.tsx,
                              #   skymarshal/{models/enums.ts, managers/SearchManager.ts}
                              # — has an internal engagement-weight split (see Gotchas)
  sister-templates/           # xcodegen patterns from alt-text-apple
  docs/                       # Reference docs from earlier phases
PROJECT_PLAN.md, MIGRATION.md, README.md, AGENTS.md   # Planning artifacts at repo root
```

The Python and React clients here are **read-only references**. To run them, go to their actual repos. Architecture facts below cite `reference/python/...` paths because those are now the on-disk locations of the canonical port targets.

## Architectural facts that span files

1. **`ContentService` is the porting boundary.** `reference/python/services/content_service.py` exposes `login() / ensure_content_loaded() / search(SearchRequest) / delete(uris) / summarize()`. The iOS `SkymarshalCore/Services/ContentService.swift` mirrors this surface and is the dependency root for every view.
2. **iOS uses API-paginated only.** CAR decode requires `libipld` / `cbor2` and is awkward on iOS. Python keeps both paths (CAR-first, API-fallback) — see `reference/python/data_manager.py`. iOS deliberately ships without CAR; documented in `docs/UPSTREAM_FEATURE_GAP.md`.
3. **Engagement weights are `1×L + 2×R + 2.5×Reply` — Python-derived.** Canonical at `reference/python/models.py:52-59` (`calculate_engagement_score`, `lru_cache`-memoized). iOS mirrors at `ios/SkymarshalCore/Models/ContentItem.swift:109-127`. Python also has a SQLite `EngagementCache` (age-tiered TTLs 1h/6h/24h/7d); iOS uses in-memory only. **The web client at `reference/web/` has an internal split:** `skymarshal/models/enums.ts:138-141` declares `replies: 3` and `managers/SearchManager.ts:325-336` uses it for sort/filter, but `pages/ContentManagement.tsx:56` uses `2.5` for display. The web bug is on the web team; iOS stays at 1/2/2.5.
4. **429 backoff is sacred.** Python `reference/python/deletion.py` and iOS `SkymarshalCore/Standards/RateLimit.swift` both use `[1, 2, 4, 8, 15, 30, 60, 120]` seconds. Bluesky PDS limit is ~5,000 writes/hour/account; a 50k-post nuke is wall-clock-bound at ~10 hours minimum *before* 429s. **Never simplify the ladder.**
5. **Per-handle isolation.** Python stores under `~/.skymarshal/{cars,json,backups}/<handle>/…`. iOS uses SwiftData with `AnalyzedAccountRecord.compositeKey = "<owner>|<did>"` as the unique-constraint key and `ModelContext`-per-call for actor safety.

## Commands

```bash
# Proposed Capacitor v1.1/alternative lives in ~/workspace/skymarshal-web:
#   cd ~/workspace/skymarshal-web && pnpm exec vite build && pnpm exec cap sync ios
#   then build the "App" scheme (ios/App/App.xcodeproj). See CAPACITOR_WRAPPER.md.
# Native iOS
cd ios
xcodegen generate                  # regenerate Skymarshal.xcodeproj from project.yml
xcodebuild -scheme Skymarshal -destination 'generic/platform=iOS Simulator' build

# Tests need a real simulator device, not the generic destination. This machine
# ships iOS runtimes with NO devices created, and `name=iPhone 17` resolves
# against OS:latest (27.0) — so it fails if your device is on an older runtime.
# Create one, then target it by UDID:
#   xcrun simctl create "iPhone 17" com.apple.CoreSimulator.SimDeviceType.iPhone-17 \
#     com.apple.CoreSimulator.SimRuntime.iOS-26-5
xcodebuild -scheme Skymarshal -destination "id=$SIM_UDID" \
  -skip-testing:SkymarshalUITests/ScreenshotTest test

xcodebuild -scheme Skymarshal -destination 'generic/platform=iOS' archive -archivePath build/Skymarshal.xcarchive

# fastlane — run under a UTF-8 locale (LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8) or any
# curly quote / em dash in the notes dies with "invalid byte sequence in US-ASCII".
# Lanes read ~/.appstoreconnect/api_key.json; env.sh is stale (rotated-out key).
cd ios && fastlane asc_state           # read-only: what is ACTUALLY live vs. in review
cd ios && fastlane release_testflight  # xcodegen + archive + upload
cd ios && fastlane testflight_notes    # attach what_to_test.txt, distribute to internal
cd ios && fastlane submit_for_review   # align ASC version, attach build, submit
cd ios && fastlane screenshots         # capture both device classes via XCUITest
cd ios && fastlane upload_screenshots  # refuses partial/stale/unequal sets (SKY_ALLOW_PARTIAL=1 to force)
cd ios && fastlane upload_listing      # metadata only, from ios/fastlane/metadata/

# Feature-flag toggles for UITest / dev runs
# Pass via scheme arguments: -sm.feature.wordPatterns YES, -sm.feature.visualizationHub YES, etc.

# Reference snapshots (NOT runnable from this repo — the canonical clients live elsewhere)
# reference/python/ — copy into a real Python project to run
# reference/web/    — copy into a real Vite project to run
```

## Gotchas worth knowing before you touch the code

- **iOS uses `ContentType.REPLIES`, not `.COMMENTS`.** AT Protocol calls them "replies" (the field on `app.bsky.feed.post`). Python `reference/python/models.py` still has a `COMMENTS` legacy value; iOS does not carry it forward.
- **Web client engagement-weight split** — when reading `reference/web/` for parity, note `skymarshal/models/enums.ts:138-141` says `replies: 3` and `SearchManager.ts:336` honors it, but `pages/ContentManagement.tsx:56` uses `2.5`. iOS sides with Python (2.5). The web bug is on the web team — don't propagate the 3 into iOS.
- **Resumable-delete breadcrumb is chunked, not per-item** (fixed 2026-06-10). `DeleteBatchRecovery.markCompleted` trims confirmed deletions every ~25 successes inside the `ContentService.delete` loop; the breadcrumb self-clears when empty. Do NOT clear it unconditionally after a batch — what remains after a cancel/halt is exactly the unconfirmed set.
- **`Retry-After` / `ratelimit-reset` are parsed** (fixed 2026-06-10). `performRaw` threads the server wait into `ATProtoError.retryAfterSeconds`; `RateLimit.withBackoff` prefers it (clamped to 120s) over the ladder. The fixed `[1,2,4,8,15,30,60,120]` ladder remains the fallback — never simplify it.
- **All server-timestamp parsing goes through `ATProtoDate.parse`** (fixed 2026-06-10). A bare `ISO8601DateFormatter` rejects the fractional-second timestamps the official client writes; nil dates used to pass date filters, which made date-scoped bulk deletes select the whole archive. Date predicates in `SearchRequest` fail closed — never let a nil `createdAt` match an active date filter.
- **Refresh failures triage network vs auth** (fixed 2026-06-10). Only a 400/401 from `refreshSession` clears the Keychain (`ATProtoClient.isDefinitiveAuthRejection`); timeouts/5xx keep the session. Bulk deletes pace at ~3,200/hr past a 300-item burst (`DeletePacing`), halt after 10 consecutive failures, and honor cancellation between items.
- **JWT pre-expiry refresh isn't done.** `ATProtoClient.swift` refreshes reactively on 401. ATProtoKit's `ensureValidToken()` decodes the JWT `exp` claim and refreshes if `<= now + 10s`. One fewer round-trip per stale-token call — file under "convention worth borrowing from ATProtoKit without taking the dep."
- **UTF-8 byte-offset facet parsing trap.** AT Proto facet `byteStart` / `byteEnd` are UTF-8 byte indices. When post bodies eventually render tappable mentions/links, `NSRange` / `String.Index` math will silently corrupt offsets on any emoji or non-ASCII character. Use `text.utf8.distance(...)` with `samePosition(in: text.utf8)`.
- **No-SPM-deps stance is sustainable for ~8 endpoints**, not forever. Trigger to adopt ATProtoKit (or similar): (a) rich-text facet emission for posting, or (b) lexicon drift outpacing hand-rolled `ATProtoTypes.swift`. Neither is in the v1.x brief.

## Native iOS source — live in the App Store

The source at `ios/` is version 1.1.0 / build 52, submitted 2026-08-05 and awaiting review. **1.0.3 is the live App Store version** (verified against ASC, not inferred from git). Architecture:

- **xcodegen-driven** — `ios/project.yml` is canonical; `Skymarshal.xcodeproj` regenerates from it. Never edit the xcodeproj directly.
- **Two-target framework split** — `SkymarshalCore` (framework, all models / services / standards / network / storage, no SwiftUI), `Skymarshal` (app, SwiftUI views + AppModel observer).
- **iOS 17+ floor** — `@Observable`, SwiftData, modern `.searchable`, `.contentMargins` all required. iOS 26 Liquid Glass is intentional system rendering (TabView floats as a pill) — lean in, don't override.
- **AT Protocol over plain `URLSession`** — `ATProtoClient` wraps `bsky.social/xrpc/...` + `public.api.bsky.app/xrpc/...`. No third-party Swift SDK. Zero SPM dependencies.
- **Per-handle SwiftData isolation** — `AnalyzedAccountRecord.compositeKey = "<owner>|<did>"` for unique constraints. `ModelContext`-per-call pattern (actor-safe).
- **429 backoff `[1, 2, 4, 8, 15, 30, 60, 120]`** lives in `RateLimit.withBackoff` and is sacred. Never simplify.
- **Engagement weights `1×L + 2×R + 2.5×Reply`** — Python-derived, NOT the TS web's `1/2/3`. Match Python.
- **Bot scoring** — `BluescreenAnalyzer` produces a 0–1 score plus an array of human-readable `botFlags`. The user-facing surface says "automation signals" / "Patterns we noticed" (dignity rename); internals keep "bot". `AnalyzedAccount.userWhitelisted` is the per-account override that exempts the account from the `showBots` filter regardless of score.
- **Keychain for session tokens**; never persist passwords. App passwords (not main) are surfaced in the LoginView copy.
- **CAR decoding skipped on iOS** — paginated API is fine for the MVP, avoids libipld.

## Visual standards (iOS port)

These are load-bearing across every SwiftUI view and easy to break by accident. Audit any new view against this list.

- **`Theme` tokens are the single source of status colors.** `Theme.danger / .caution / .warn / .scope / .success / .info / .like` (defined in `SkymarshalCore/Standards/Theme.swift`) via `UIColor(dynamicProvider:)` so light/dark variants clear WCAG 1.4.11 ≥3:1 against `systemBackground`. Never write `.red` / `.orange` / `.yellow` / raw RGB literals — they fail contrast in one mode or the other.
- **`ReduceMotion.shouldReduce(systemReduceMotion:)` is the single helper** every animation site routes through. ORs the system `accessibilityReduceMotion` env value with the user's `@AppStorage("sm.reduceMotionOverride")` toggle. Pattern: `private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }`.
- **Menu trigger labels are icon + short word only.** Verbose dynamic text ("Sort: Followers", "Bots: Balanced") wraps inside iOS 26's circular Menu shape on real device. Current state goes in the Picker dropdown's checkmark, not the trigger label. `.accessibilityLabel` on the Menu carries the full meaning for VoiceOver.
- **SF Symbols on tinted chip backgrounds get `.symbolRenderingMode(.monochrome)`** — iOS 26's dynamic color system auto-selects fallbacks that render mid-size symbols as emoji-like glyphs without an explicit rendering mode.
- **Horizontal ScrollView overflow indicator: `.contentMargins(.trailing, 24, for: .scrollContent)`** — gives the last item a deliberate ~24pt gutter so it rests with a visible "more on the right" affordance instead of being cut mid-character. Mirrors Apple Mail's category-row treatment. Incompatible with `.scrollClipDisabled()` — pick one.
- **iOS 26 Liquid Glass is intentional on TabView.** The floating pill tab bar at the bottom is system rendering when running on iOS 26 even with iOS 17 deployment target. Do NOT apply `.glassEffect()` to list rows / count pills — Liquid Glass is exclusively for the navigation layer.
- **Row min-height ≥ 44pt** on ContentRow + AccountRow (Apple HIG floor). Bio + bot badge dense rows justify 56–60pt; this is a v1.0.1 polish item.
- **Destructive actions ≥ 100 items go through `TypedConfirmSheet`** (`Skymarshal/UI/TypedConfirmSheet.swift`) — explicit "DELETE" typed-confirm gate. Smaller batches use the standard `confirmationDialog`. The metaphor-heavy delete message ("leaves the building") was retired in favor of literal copy.
- **Brand voice**: "Air-traffic control for your Bluesky" — spy-bird AppIcon + dot-matrix LoginView header + scope motif. Never replace.
- **Out of scope unless asked**: firehose, network graphs, bot detection beyond Bluescreen's existing scoring, follower cleanup beyond the existing surface, sentiment scoring, analytics dashboards, content sharing.

## Competitive landscape (scout snapshot, useful for App Store positioning)

- **No iOS-native competitor** in the Bluesky content-cleanup category as of May 2026. Direct competitors are web-only: [BskyDelete](https://bskydelete.com) (free, open source, browser-local tokens), [Redact](https://redact.dev/services/bluesky) (freemium, multi-platform), [Bluesky Repo Explorer](https://romiojoseph.github.io/bluesky/bluesky-repo-explorer/) (free, GitHub Pages), [Circleboom](https://circleboom.com) (paid suite).
- **iOS Bluesky clients exist but are feed-readers, not cleanup tools**: the official app, Graysky, Skeets, Croissant. Skymarshal occupies a different shelf.
- **Twitter/X analog pricing band** for "delete your posts" prosumer apps: $4–15/mo or $14.99 one-time (TweetDelete.net is the closest one-time reference).
- **Bluesky 2026 roadmap signals**: no native bulk-delete in the Jan 2026 "What's Next" post. "Deeper third-party app support" is mildly positive signal. Treat as a *signal* not a moat — the lane is open partly because Apple review risk is real and Bluesky may eventually ship this themselves.
- **Swift AT Protocol SDKs exist** ([ATProtoKit](https://github.com/MasterJ93/ATProtoKit), [swift-atproto](https://swiftpackageindex.com/andooown/swift-atproto)). Skymarshal intentionally avoids them — see "no-SPM-deps" gotcha for the adoption trigger.

## Council checklist (v1.0.x — shipped 2026-07-20)

May 2026 `/team:team` verdict, updated by the 2026-06-10 adversarial review (cynic + breaker + executive; full log in `PROJECT_PLAN.md`). **The app shipped and is live; the pre-submission gate is closed.** Focus is now v1.1+ work.

**Done (verified 2026-06-10):**
- ✅ Breadcrumb per-success state — chunked `DeleteBatchRecovery.markCompleted` inside the delete loop + recovery tests.
- ✅ Pre-flight wall-clock estimate — `DeletePacing.formattedEstimate` in `TypedConfirmSheet`.
- ✅ User-facing Bluescreen rename — zero user-facing "Bluescreen" strings remain (tab "Followers", copy "Patterns we noticed"). Internal codenames stay.
- ✅ Reviewer notes cite `com.atproto.repo.deleteRecord` (`app-store/SUBMISSION_NOTES.md` + `ios/fastlane/metadata/review_information/notes.txt`).
- ✅ Content tab CSV/JSON export (`Exporter.swift` pattern; never `Transferable`/`ShareLink` — commit `5e3e66a`).
- ✅ Alt-text search — covered by `includeAltTextInKeyword`; the dedicated `altTextContains` field was dropped as redundant.
- ✅ Date-parse safety, refresh triage, Retry-After parsing, delete pacing/cancel/circuit-breaker, 20k truncation banner, SwiftData duplicate-key guard (breaker findings — see Gotchas).

**Pre-submission gate — closed by launch (2026-07-20).** Remaining item carried forward:
- Timeframe quick-filter chips (7d/30d/90d/1y) — last open parity item, now a v1.1 candidate.

**v1.1 candidates (after launch):**
- ~~Ghost likes via `com.atproto.repo.listRecords`~~ — **done.** `ContentService.reconcileGhostLikes` diffs the repo's `app.bsky.feed.like` records against what `getActorLikes` hydrated; the remainder are ghosts, flagged `ContentItem.subjectUnresolved`, deletable through the normal path. Two rules matter: reconcile **only** when the hydrated sweep ran to exhaustion (otherwise an unpaginated like is indistinguishable from a ghost), and never let a failed repo read fail the whole archive load.
- "Danger Zone" bulk-by-category delete (all likes / all reposts / all follows) — pair with `TypedConfirmSheet` + countdown + the 429 ladder.
- Per-item delete parade (Python's `DeleteMode.INDIVIDUAL`).
- Paywall decision (launch is free, no IAP — decided 2026-06-10; grandfather early adopters if one ships).

**Kill criteria (restated measurably 2026-06-10; canonical copy in `PROJECT_PLAN.md`):**
- **Ship-blocker.** ~~Rejection citing 5.0 or 4.3 on content-deletion grounds~~ — **moot: approved and live 2026-07-20.**
- **Pivot-trigger.** Bluesky ships/announces native bulk-delete-by-filter (checked monthly, next 2026-07-10) / action: drop deletion as headline within 30 days; reposition around Patterns + alt-text audit.
- **Sunset-trigger.** By 2026-12-10: <300 App Analytics opt-in downloads AND <25 ratings AND (if IAP shipped) <30 unlocks / action: archive iOS target, maintain Python CLI only.

## Marketing copy rules (apply to App Store listing too)

- Never use "AI", "AI-powered", "AI-enhanced", "AI-driven". If LLM features ever land, say "the on-device language model" or name the model.
- Don't reference internal tooling (skill names, agent names, "humanize", `/team`, etc.) in any user-facing prose, README, changelog, or release note.
- Author is Luke Steuber. Do not add `Co-Authored-By` to git commits.
