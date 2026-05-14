# Project plan — Skymarshal iOS

Living snapshot of objectives and boundaries. Product copy and build commands stay in [`README.md`](README.md); contributor rules in [`AGENTS.md`](AGENTS.md).

## Current milestone

- **Distribution:** Pre–public TestFlight; public link pending Beta App Review ([`README.md` Status](README.md)).
- **Quality bar:** Full `xcodebuild test` green before release-worthy changes; preserve 429 backoff and deletion URI semantics ([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).

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
- Keep README test counts / build numbers aligned with CI or manual verification after substantive changes (current `SkymarshalTests`: **185** `func test_` methods).

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

Remaining:

- Confirm final screenshot exports for required iPhone size classes.
- Verify marketing, support, and privacy pages are live and consistent with listing language.
- Execute paste session and submit release build.
- Prepare 72-hour post-launch support and review-response cadence.
