# Architecture (native iOS)

This document describes the **shipping** SwiftUI app. Historical Python CLI architecture (manager pattern, CAR pipelines, Flask) lives in [`reference/docs/ARCHITECTURE.md`](../reference/docs/ARCHITECTURE.md) — useful for provenance only.

## Layers

| Layer | Location | Responsibility |
|-------|----------|------------------|
| **App + UI** | [`ios/Skymarshal/`](../ios/Skymarshal/) | SwiftUI views, [`AppModel`](../ios/Skymarshal/UI/AppModel.swift), navigation, accessibility. |
| **Core** | [`ios/SkymarshalCore/`](../ios/SkymarshalCore/) | Models, AT Protocol client, services, SwiftData storage, shared standards. |

Targets and XcodeGen: [`ios/project.yml`](../ios/project.yml). Do not hand-edit the generated `.xcodeproj` when settings belong in the YAML.

## Orchestration boundary

[`ContentService`](../ios/SkymarshalCore/Services/ContentService.swift) (Swift `actor`) mirrors the Python orchestrator [`reference/python/services/content_service.py`](../reference/python/services/content_service.py): login, load archive into SwiftData, search, delete, summaries. **Views should call this surface** rather than duplicating fetch/delete flows.

Companion services:

- [`FollowerService`](../ios/SkymarshalCore/Services/FollowerService.swift) — follow graph fetch, Bluescreen scoring hooks.
- [`InteractionService`](../ios/SkymarshalCore/Services/InteractionService.swift) — mutual interaction history.
- [`ProfileService`](../ios/SkymarshalCore/Services/ProfileService.swift) — paginated `getFollowers` / `getFollows` for the profile explorer (read-only graph lists).
- [`AnalyticsService`](../ios/SkymarshalCore/Services/AnalyticsService.swift) — pure-function snapshots from cached [`ContentItem`](../ios/SkymarshalCore/Models/ContentItem.swift) data (no network).

### Imported upstream-adjacent surfaces (roadmap tranche)

- **On-device insights:** [`AnalyticsInsightsView`](../ios/Skymarshal/UI/AnalyticsInsightsView.swift) + [`AnalyticsSnapshot`](../ios/SkymarshalCore/Models/AnalyticsSnapshot.swift).
- **Power search:** [`ContentSortOrder`](../ios/SkymarshalCore/Models/ContentSortOrder.swift), [`SavedSearchPresetRecord`](../ios/SkymarshalCore/Storage/StorageModels.swift), [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) ellipsis menu.
- **Cleanup presets:** [`CleanupPreset`](../ios/SkymarshalCore/Models/CleanupPreset.swift) applied to [`FollowerFilters`](../ios/SkymarshalCore/Models/FollowerFilters.swift).
- **Rollout toggles:** [`FeatureFlags`](../ios/SkymarshalCore/Standards/FeatureFlags.swift) (`UserDefaults`, keys prefixed `sm.feature.`).

## Network and storage

- **HTTP:** [`ATProtoClient`](../ios/SkymarshalCore/Network/ATProtoClient.swift) — `URLSession` only, no third-party ATProto SDK; Bluesky hosts `bsky.social` / `public.api.bsky.app`.
- **Persistence:** SwiftData schemas in [`Storage/`](../ios/SkymarshalCore/Storage/StorageModels.swift); per-account isolation via composite keys (see [`AGENTS.md`](../AGENTS.md)).
- **Rate limits:** [`RateLimit.withBackoff`](../ios/SkymarshalCore/Standards/RateLimit.swift) preserves the Python deletion backoff schedule — do not simplify.

## Standards (non-negotiables)

| Concern | Implementation |
|---------|----------------|
| Status colors | [`Theme`](../ios/SkymarshalCore/Standards/Theme.swift) — no raw `.red` / ad hoc RGB for semantic states. |
| Motion | [`ReduceMotion.shouldReduce`](../ios/SkymarshalCore/Standards/ReduceMotion.swift) at animation sites. |
| Follower automation signals | [`BluescreenAnalyzer`](../ios/SkymarshalCore/Standards/BluescreenAnalyzer.swift). |

## Contributor UX (SwiftUI)

Shipped screens should stay visually and behaviorally coherent — menus, chips, destructive flows, and motion are part of the architecture boundary for this app. See **[`docs/CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md)** for the condensed checklist (Theme, ReduceMotion, Liquid Glass scope, horizontal scroll margins, dry-run vs per-account unfollow scope).

### User-facing contracts (roadmap surfaces)

- **Insights:** Pure on-device aggregation over cached [`ContentItem`](../ios/SkymarshalCore/Models/ContentItem.swift); no network in [`AnalyticsService`](../ios/SkymarshalCore/Services/AnalyticsService.swift). Copy must not imply third-party analytics SDKs.
- **Power search:** Presets and sort are account-scoped via SwiftData (`SavedSearchPresetRecord`); failures should surface to the user where possible (avoid silent decode drops without recovery UI).
- **Profile explorer:** Paginated graph reads via [`ProfileService`](../ios/SkymarshalCore/Services/ProfileService.swift); subject to latency, cursoring, and rate limits — UI should tolerate empty/partial pages.
- **Dry-run unfollow:** When enabled in [`BluescreenView`](../ios/Skymarshal/UI/BluescreenView.swift), both bulk and account-detail paths pass `dryRun: true` into [`FollowerService.unfollow`](../ios/SkymarshalCore/Services/FollowerService.swift) — no network writes, list unchanged for preview.

## Reference tree

[`reference/README.md`](../reference/README.md) explains the frozen Python + TypeScript snapshot. **Python wins** on behavioral disputes with TS (backoff, engagement weights) — see [`MIGRATION.md`](../MIGRATION.md).

## Further reading

- Documentation hub (all `docs/` entry points): [`README.md`](README.md)
- Contributor workflow: [`AGENTS.md`](../AGENTS.md)
- Contributor SwiftUI / destructive-flow checklist: [`CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md)
- Lift provenance and drift rules: [`MIGRATION.md`](../MIGRATION.md)
- Upstream (Python / Flask / web / npm) vs iOS scope: [`UPSTREAM_FEATURE_GAP.md`](UPSTREAM_FEATURE_GAP.md)
- Large-branch review package: [`TEAM_CONSENSUS_DECISION_PACKAGE.md`](TEAM_CONSENSUS_DECISION_PACKAGE.md)
- App Store submission notes: [`app-store/`](../app-store/)
