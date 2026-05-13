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

- Row min-height: **ContentRow** / **AccountRow** use **56 pt** minimum (see [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md)); further density polish remains non-blocking.
- Keep README test counts / build numbers aligned with CI or manual verification after substantive changes (current `SkymarshalTests`: **164** `func test` methods).

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
- **Consensus run (partial):** External CLIs/APIs did not complete in automation; **session synthesis** captured in [`docs/archive/consensus-skymarshal-ios-2026-05-13.md`](docs/archive/consensus-skymarshal-ios-2026-05-13.md) with verdict matrix and re-run instructions. Prompt: [`docs/archive/consensus-skymarshal-ios-PROMPT.txt`](docs/archive/consensus-skymarshal-ios-PROMPT.txt).
- **Re-run locally:** `gemini -p "$(cat docs/archive/consensus-skymarshal-ios-PROMPT.txt)"` and/or `codex exec …` from repo root; merge new columns into the archive markdown when voices return.

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
