# Project plan — Skymarshal iOS

Living snapshot of objectives and boundaries. Product copy and build commands stay in [`README.md`](README.md); contributor rules in [`AGENTS.md`](AGENTS.md).

> **Direction change — 2026-06-21: explored "Option B" (Capacitor web-wrapper).**
> A Capacitor wrapper of the
> `skymarshal-web` React client (`skymarshal.blue`) — validated end-to-end, living
> in `~/workspace/skymarshal-web` (branch `feature/ios-capacitor-wrapper`; see
> `CAPACITOR_WRAPPER.md`) remains a proposed v1.1/alternative. This native repo is
> active again for parity and release hardening and remains the **reference + source** for
> the deletion engine (ported as `SkymarshalDeletePlugin.swift`) and behavior
> parity. An explicit shipping decision is still required before either path is
> described as the current distributed build.

> **2026-07-13 — Figma Make visual landed on native chrome.** OLED void/elev
> surfaces, accent gradient tokens, tab IA Content / Patterns / Scope / About
> (Scope default-on), Delete Review typed-confirm restyle. The Capacitor prototype
> remains available; this keeps native parity with the Make prototype.
>
> **2026-07-13 — Parity pass 2.** List rows → elev1, banners/chips → elev+hairline
> (no thinMaterial), Type/ActiveFilter chips radius-sm + Mono, Filter sheets
> cinematic chrome, Login elev2 wells, Bots menu icon+short word, Scope drill-ins
> void chrome. Still open vs Make: List-vs-Card row model, search field chrome,
> toolbar strips beyond type chips.
>
> **2026-07-13 — Parity pass 3 (local Make export).** Source:
> `~/Downloads/skymarshal-figma`. Content/Patterns: elev2 `CinematicSearchField`
> (replaced `.searchable`), void + hairline list rows, Patterns
> Strict/Balanced/Loose segment. Scope hub: elev1 Card rail matching Make.
>
> **2026-07-13 — Parity pass 4 (five-gap closeout).** Content and Patterns now
> use large in-page titles with live handle/count subtitles. Patterns rows show
> inline automation-signal bars and accessible expandable evidence. Scope has
> real-cache Account Graph, Post Graph, Interactions, and heatmap drill-ins
> (no Make fixture data). First-run onboarding is a four-step, skippable
> carousel. Advanced Search now follows Make's required/excluded/phrase/type/
> date IA with a live on-device estimate while preserving native media,
> engagement, subject, and DID filters under More filters.

## Current milestone

- **Source release:** Native v1.0.3 / build 44. Version 1.0.2 / build 40 is **live in the App Store as of 2026-07-20**, with login verified in production. The submission gate in [`docs/SUBMISSION_DECISION.md`](docs/SUBMISSION_DECISION.md) is closed.
- **Launch pricing (decided 2026-06-10):** Free, no IAP at launch. Supersedes the 2026-05-14 tiering ($2.99/mo / $19.99/yr / $49.99 lifetime). A paywall is a v1.1 decision; early adopters get grandfathered if one ships.
- **Quality bar:** Full `xcodebuild test` green before release-worthy changes; preserve 429 backoff and deletion URI semantics ([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).
- **Invalid-handle safety:** `handle.invalid` is an unverified-handle sentinel only. Native scans prefer the detailed profile handle, status-based bulk filters do not infer bot/deleted/inactive state from the sentinel, and cold-start hydration recomputes only affected cached scan rows.

## Expansion plan (approved for planning)

Goal: bring upstream CLI/web parity surfaces into iOS with explicit safety gates, and add account/post/interaction visualizations.

Canonical roadmap:

- [`docs/PARITY_VISUALIZATION_PLAN.md`](docs/PARITY_VISUALIZATION_PLAN.md) — phased delivery, risk register, visualization architecture, 90-day plan.
- [`docs/UX_SPEC.md`](docs/UX_SPEC.md) — IA and screen-level behavior for advanced search, delete review, backup center, visualization hub.
- [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) — visual language + accessibility/performance rules for graph-heavy surfaces.

## Existing roadmap tranche (already shipped)

Shipped in-repo: on-device **Insights** analytics, **saved search presets**, **content sort**, **cleanup presets**, **dry-run unfollow**, **profile explorer** (followers/following lists). Toggle keys live in [`FeatureFlags`](ios/SkymarshalCore/Standards/FeatureFlags.swift).

## Merge and review discipline (large tranches)

- Canonical facts + decision question for council review: [`docs/REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md`](docs/REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md).
- Synthesized `/team` + `/consensus` outcomes, Option A vs B, and pre-merge gates: [`docs/TEAM_CONSENSUS_DECISION_PACKAGE.md`](docs/TEAM_CONSENSUS_DECISION_PACKAGE.md).
- SwiftUI contributor checklist (Theme, motion, menus, known dry-run scope): [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md).

## Near-term polish (non-blocking)

- **Reliability + review docs:** Archive load checkpoints ([`docs/ARCHIVE_LOAD_CHECKPOINTS.md`](docs/ARCHIVE_LOAD_CHECKPOINTS.md)), device soak gate ([`docs/SOAK_PROTOCOL.md`](docs/SOAK_PROTOCOL.md)), consensus implementation delta ([`docs/archive/consensus-skymarshal-ios-delta-2026-05-14.md`](docs/archive/consensus-skymarshal-ios-delta-2026-05-14.md)), Scope IA placeholder ([`docs/archive/scope-ia-decision-2026-05-14.md`](docs/archive/scope-ia-decision-2026-05-14.md)).
- Row min-height: **ContentRow** / **AccountRow** use **56 pt** minimum (see [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md)); further density polish remains non-blocking.
- Keep README test counts / build numbers aligned with CI or manual verification after substantive changes (2026-07-18: **275 unit tests + 12 non-credential UI tests passing**).

## Session refresh & Keychain persistence (2026-05-13)

Reliability fix landed in response to the in-the-wild report: "after a time, it loses auth and then throws atproto errors everywhere unless the user logs out and back in manually." Root cause was a two-part gap — the AT Protocol access JWT expires after ~2 hours but [`ATProtoClient`](ios/SkymarshalCore/Network/ATProtoClient.swift) never called `com.atproto.server.refreshSession`, and the session lived only in memory so a cold start always landed on LoginView. The fix:

- New [`SessionStore`](ios/SkymarshalCore/Standards/SessionStore.swift) persists the rotating `(accessJwt, refreshJwt)` pair to the iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no iCloud sync). The app password is never written to disk.
- [`ATProtoError`](ios/SkymarshalCore/Standards/RateLimit.swift) now parses the structured XRPC error envelope so `isExpiredToken` is reliable across the `ExpiredToken` / `InvalidToken` / `AuthenticationRequired` codes the PDS returns on 400 and 401.
- [`ATProtoClient.perform(_:)`](ios/SkymarshalCore/Network/ATProtoClient.swift) catches the expired-token error, refreshes once via `com.atproto.server.refreshSession`, and replays the original request with the new bearer. Concurrent refreshes are coalesced through a single `refreshTask`.
- When refresh itself fails (refresh JWT expired/revoked) the client clears local + Keychain state and posts `Notification.Name.skymarshalSessionInvalidated`. [`AppModel`](ios/Skymarshal/UI/AppModel.swift) observes that signal, clears the in-memory snapshots so RootView flips back to LoginView, and surfaces a one-shot `sessionExpiredNotice` banner there instead of letting the bare ATProtoError reach the user.
- [`RootView`](ios/Skymarshal/UI/RootView.swift) calls `AppModel.tryRestoreSession()` in its cold-start `.task` so the LoginView is skipped whenever a valid refresh JWT (3-month TTL) is on disk.
- 18 new XCTest cases in `SkymarshalTests/SessionRefreshTests.swift` cover XRPC error parsing, `isExpiredToken` detection across statuses, and a Keychain round-trip.

## Parity + visualization (on main, 2026-05)

Shipped behind `sm.feature.*` defaults **off**: advanced keyword grammar + builder UI, delete preflight in confirm flows, graph snapshot models + writer, visualization hub (Scope tab), word-pattern stats in Insights, JSON backup import + About entry. Canonical spec remains [`docs/PARITY_VISUALIZATION_PLAN.md`](docs/PARITY_VISUALIZATION_PLAN.md); architecture links in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Explicit non-goals (unless requested)

- Firehose and hosted analytics backends.
- Full on-device CAR decode remains deferred until Phase 3 feasibility gates pass.
- Third-party AT Protocol SDKs; dependency-free `URLSession` remains the rule.
- Marketing copy using “AI” framing ([`app-store/`](app-store/) and in-app voice).

## Technical anchors

- Orchestration: [`ios/SkymarshalCore/Services/ContentService.swift`](ios/SkymarshalCore/Services/ContentService.swift).
- Behavioral parity with Python reference: [`MIGRATION.md`](MIGRATION.md), [`reference/README.md`](reference/README.md).
- Full upstream vs iOS scope map (not a port backlog): [`docs/UPSTREAM_FEATURE_GAP.md`](docs/UPSTREAM_FEATURE_GAP.md).

## Council + consensus (2026-05-13)

- **`/team` kill criteria (echo):** Do not ship if viewer **`deletionURI`** mapping or **429 backoff** regresses; pivot if demand is primarily a full Bluesky client; sunset if AT/XRPC + solo maintenance + revenue no longer align.
- **Consensus run:** **Codex** (`gpt-5.5`, read-only) and **Claude Code** (`claude -p`) completed 2026-05-13; merged matrix + raw appendices in [`docs/archive/consensus-skymarshal-ios-2026-05-13.md`](docs/archive/consensus-skymarshal-ios-2026-05-13.md). Prompt: [`docs/archive/consensus-skymarshal-ios-PROMPT.txt`](docs/archive/consensus-skymarshal-ios-PROMPT.txt). **Gemini CLI** prior attempt: HTTP 499; **cursor-agent**: auth skipped.
- **Re-run / extend:** `gemini` retry in full terminal; optional API voices from `~/documentation/API_KEYS.md` per `/consensus` skill. Codex: `cat docs/archive/consensus-skymarshal-ios-PROMPT.txt | codex exec --skip-git-repo-check -c 'sandbox_mode="read-only"' -`

## Release ops addendum (2026-05-12)

Objective: keep public App Store release prep executable end-to-end from docs.

Completed:

- Added `app-store/PUBLIC_RELEASE_PACK.md` as the release index.
- Added `app-store/PUBLIC_RELEASE_COPY.md` with paste-ready listing and launch copy.
- Added `app-store/PUBLIC_RELEASE_ASSETS.md` with iOS asset requirements and QA checks.
- Added `app-store/PUBLIC_RELEASE_RUNBOOK.md` with pre-submit and launch operations.
- Added `app-store/APP_STORE_CONNECT_PASTE_SESSION.md` with exact App Store Connect field order.
- Reconciled drift across listing/paste-session/review-note docs with a canonical hierarchy in `app-store/PUBLIC_RELEASE_PACK.md`.
- Updated `README.md` with direct links to the release pack.

Remaining (status as of 2026-05-14):

- **Bundle ID + App Store Connect record creation** at developer.apple.com / appstoreconnect.apple.com (see `app-store/SUBMISSION_NOTES.md` lines 195–216 checklist).
- **Refresh screenshots** per `app-store/SCREENSHOTS.md` when the UI changes. Five iPhone 6.9-inch and five iPad 13-inch PNGs are staged; add a widget frame after an authentic neutral demo capture.
- **Demo account for App Review.** `app-store/SUBMISSION_NOTES.md` currently declines to provide one; recommend creating `skymarshal-review.bsky.social` + app password and pasting into the App Review Information block to avoid one rejection cycle.
- **Soak protocol artifact** per `docs/SOAK_PROTOCOL.md` — physical device, ≥10k-post account, full screen-recorded session. Required before promoting from TestFlight to public.
- **Paste session execution** per `app-store/APP_STORE_CONNECT_PASTE_SESSION.md`.
- **72-hour post-launch support + review-response cadence** prepared from `app-store/PUBLIC_RELEASE_RUNBOOK.md`.

Already verified (2026-05-16):

- `https://skymarshal.blue`, `/support`, and `/privacy.html` resolve HTTP 200.
- Build 5 (auth-refresh + Keychain + visual restyle) tested at 185 / 185 green. `CFBundleVersion` is 5 and `MARKETING_VERSION` is back at 1.0.0 — the v1.0.1 working label was retired (commit `9ca2e84`) since nothing was ever released. Build 5 carries the cumulative work as the in-progress 1.0.0.
- Required-Reason API audit: only `UserDefaults` is directly used by app code; declared with CA92.1 in `PrivacyInfo.xcprivacy`. No file-timestamp / boot-time / disk-space / active-keyboard usages.

## Council pre-ship checklist (2026-05-16)

Full action items in [`CLAUDE.md` § Council pre-ship checklist](CLAUDE.md). Summary:

- **Ship-blocker.** `DeleteBatchRecovery` breadcrumb writes once at delete-start and never per-success (`ios/SkymarshalCore/Services/DeleteBatchRecovery.swift:22-30` + `ContentService.swift:289-318`). Fix ~5 LOC + a recovery test.
- **Ship-blocker.** Pre-flight estimated wall-clock for any bulk delete ≥ 1,000 items. PDS quota math: 50k items = 10+ hours.
- **Ship-blocker.** 15-min USPTO TESS check on "Skymarshal" in the software-utility class.
- **Ship-blocker.** Rename user-facing "Bluescreen" → "Patterns" or "Signals" in App Store listing copy + in-app labels. Internal codenames stay.
- **Ship-blocker.** Reviewer-notes file citing `com.atproto.repo.deleteRecord` as a documented public AT Protocol lexicon (mitigates historical 5.2.2 / 4.3 review risk seen with Twitter cleanup apps).
- **Parity gap (close before App Store).** Content tab CSV/JSON export. Follow the `Exporter.swift` Bluescreen pattern. Do NOT use `Transferable` / `ShareLink` — commit `5e3e66a` memorializes the crash.
- **Parity gap.** Alt-text search filter (one optional `altTextContains: String?` field on `SearchRequest`).
- **Parity gap.** Timeframe quick-filter chips (7d / 30d / 90d / 1y) — UI sugar over existing dates.
- **v1.1.** Danger Zone bulk-by-category delete; per-item delete parade; `Retry-After` header parse in `ATProtoClient.performRaw:453-466`.

Kill criteria preserved verbatim from cynic seat in [`CLAUDE.md`](CLAUDE.md). Competitive landscape snapshot also in CLAUDE.md.

## Adversarial review (2026-06-10) — pre-submission gates

Full findings in the session plan (cynic + breaker + executive council). Status updates to the 2026-05-16 checklist:

- **CLOSED:** Bluescreen→Patterns rename (zero user-facing "Bluescreen" strings remain; tab is "Followers", audit copy says "Patterns we noticed"). Content CSV/JSON export (`Exporter.swift`). Alt-text search (covered by `includeAltTextInKeyword`; the dedicated `altTextContains` field is dropped).
- **REOPENED then fixed 2026-06-10:** reviewer-notes lexicon citation (`com.atproto.repo.deleteRecord`) — was missing from both `app-store/SUBMISSION_NOTES.md` and `ios/fastlane/metadata/review_information/notes.txt`; both now carry it. Demo-account decline replaced with provided-credentials copy; the account itself still needs creating (manual).
- **NEW ship-blockers from the breaker pass (subsequently fixed):** tolerant `createdAt` parsing + fail-closed date filters (bare `ISO8601DateFormatter` rejected the fractional-second timestamps the official client writes, so nil-dated items passed date filters — a date-scoped bulk delete could select the whole archive); delete-loop survivability (cancellation, `Retry-After` parsing, pacing, circuit breaker, idle-timer hold); refresh-failure triage (network blips no longer wipe the Keychain session); 20k-load truncation honesty; SwiftData duplicate-key crash guard; chunked breadcrumb recovery.

### Kill criteria (restated measurably, 2026-06-10)

- **Ship-blocker (unchanged):** two App Store rejections citing 5.0/4.3 on content-deletion grounds → do not appeal a third time; pivot to PWA at skymarshal.blue.
- **Pivot-trigger (now owned):** Bluesky official app ships or announces native bulk-delete-by-filter → reposition around Patterns + alt-text audit within 30 days. Checked monthly against the Bluesky changelog/roadmap; owner Luke.
  - **2026-08-04 — checked, not fired.** No native bulk delete announced; deletion in the official app is still one post at a time. Every competitor remains web or browser-extension only (BskyDelete, Redact, Skeet Deleter, Repo Explorer). No iOS-native competitor found. Next check **2026-09-04**.
  - *The 2026-07-10 check was missed and ran 25 days late.* If this slips twice more, treat the check itself as the thing that failed and drop the monthly cadence for a release-time check instead.
- **Sunset-trigger (replaces the unmeasurable MAU/conversion version):** by 2026-12-10, fewer than 300 App Analytics opt-in downloads AND fewer than 25 ratings AND (only if an IAP has shipped) fewer than 30 unlocks → archive the iOS target, maintain the Python CLI only.

### Manual items (Luke, off-repo)

- Create + populate the `skymarshal-review.bsky.social` demo account; paste credentials into the ASC App Review sign-in fields (`app-store/DEMO_ACCOUNT.md`).
- 15-min USPTO TESS check on "Skymarshal" (software-utility class); log the result here.
- Pull 4 weeks of TestFlight installs/sessions/crash data from App Store Connect before submission; it is the only real demand signal and no document records it yet.
- Soak run per `docs/SOAK_PROTOCOL.md` after the P0 fixes land (artifact under `docs/soak/`).
