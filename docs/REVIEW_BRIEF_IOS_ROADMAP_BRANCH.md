# Canonical review brief — `cursor/ios-roadmap-imports` vs `main`

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

Shared input for `/consensus` and `/team`. Do not treat as user-facing product copy.

## Target

| Field | Value |
|-------|--------|
| Branch | `cursor/ios-roadmap-imports` |
| Base | `main` |
| Draft PR | https://github.com/lukeslp/skymarshal-ios/pull/2 |

## Commits on branch (not on `main`)

1. `7aad395` — feat: import iOS roadmap tranche for insights and cleanup  
2. `98f8f29` — docs: clarify reference tree and parity guidance  

## Delta summary (~29 files, +1259 / -144)

**SkymarshalCore**

- `AnalyticsService` + `AnalyticsSnapshot` — on-device metrics from cached content.
- `ProfileService` + `ATProtoClient` / `ATProtoTypes` — followers/following pagination.
- `FeatureFlags`, `CleanupPreset`, `ContentSortOrder`.
- `StorageModels` — `SavedSearchPresetRecord` (+ schema).
- Comment-only tightening in `ContentService`, `BluescreenAnalyzer`, `Timeout`.

**App**

- `AppModel` — saved-search CRUD, explorer hooks, flags.
- `ContentListView` — sort, presets, insights entry, quick stats.
- `AnalyticsInsightsView`, `ProfileExplorerView`.
- `AccountDetailView`, `BluescreenView` — explorer + cleanup presets / dry-run unfollow.
- `Skymarshal.xcodeproj/project.pbxproj` — new file references.

**Tests**

- `AnalyticsServiceTests`.

**Docs / reference**

- `README`, `PROJECT_PLAN`, `docs/ARCHITECTURE`, `docs/UPSTREAM_FEATURE_GAP`, `AGENTS` (if in same tranche), `MIGRATION`.
- `reference/README`, `reference/docs/CLAUDE`, `reference/docs/README`.

## Architecture notes

- `project.yml` uses directory `sources` for `Skymarshal` / `SkymarshalCore` / tests — new `.swift` files under those trees are included on `xcodegen generate`; `pbxproj` edits must stay consistent with regen workflow.
- Product guardrails: direct XRPC, no third-party AT SDK, on-device analytics, sacred 429 backoff for real writes.
- **UI / review checklist** for anyone evaluating this branch: [`CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md).

## Decision question (required answer)

**Should this ship as one merged PR, or be split into multiple PRs before merge?**

## Required outputs (from each reviewer / committee)

1. Verdict: **AGREE** (one PR) / **DISAGREE** (split) / **WAIT** (needs info) — one line with reason.  
2. **Top concrete risk** (specific failure mode, not generic “bugs”).  
3. **Highest-value pre-merge check** (single most leverage verification step).  
4. **Kill criterion** — what would block merge.  
5. **Confidence** — high / medium / low.
