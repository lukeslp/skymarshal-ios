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

## Reference tree

[`reference/README.md`](../reference/README.md) explains the frozen Python + TypeScript snapshot. **Python wins** on behavioral disputes with TS (backoff, engagement weights) — see [`MIGRATION.md`](../MIGRATION.md).

## Further reading

- Contributor workflow: [`AGENTS.md`](../AGENTS.md)
- Lift provenance and drift rules: [`MIGRATION.md`](../MIGRATION.md)
- Upstream (Python / Flask / web / npm) vs iOS scope: [`UPSTREAM_FEATURE_GAP.md`](UPSTREAM_FEATURE_GAP.md)
- App Store submission notes: [`app-store/`](../app-store/)
