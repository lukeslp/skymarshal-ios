# Architecture (native iOS)

This document describes the **shipping** SwiftUI app. Historical Python CLI architecture (manager pattern, CAR pipelines, Flask) lives in [`reference/docs/ARCHITECTURE.md`](../reference/docs/ARCHITECTURE.md) — useful for provenance only.

## Layers

| Layer | Location | Responsibility |
|-------|----------|------------------|
| **App + UI** | [`ios/Skymarshal/`](../ios/Skymarshal/) | SwiftUI views, [`AppModel`](../ios/Skymarshal/UI/AppModel.swift), navigation, accessibility. |
| **Core** | [`ios/SkymarshalCore/`](../ios/SkymarshalCore/) | Models, AT Protocol client, services, SwiftData storage, shared standards. |

Targets and XcodeGen: [`ios/project.yml`](../ios/project.yml). Do not hand-edit the generated `.xcodeproj` when settings belong in the YAML.

## Orchestration boundary

[`ContentService`](../ios/SkymarshalCore/Services/ContentService.swift) (Swift `actor`) mirrors the Python orchestrator [`reference/python/services/content_service.py`](../reference/python/services/content_service.py): login, load archive into SwiftData, search, delete, summaries. **Views should call this surface** rather than duplicating fetch/delete flows. Long loads persist **`ArchiveLoadCheckpointRecord`** cursors per owner/phase so pagination can resume after interruption; `forceRefresh` clears checkpoints alongside cached rows.

Companion services:

- [`FollowerService`](../ios/SkymarshalCore/Services/FollowerService.swift) — follow graph fetch, Bluescreen scoring hooks.
- [`InteractionService`](../ios/SkymarshalCore/Services/InteractionService.swift) — mutual interaction history.
- [`ProfileService`](../ios/SkymarshalCore/Services/ProfileService.swift) — paginated `getFollowers` / `getFollows` for the profile explorer (read-only graph lists).
- [`AnalyticsService`](../ios/SkymarshalCore/Services/AnalyticsService.swift) — pure-function snapshots from cached [`ContentItem`](../ios/SkymarshalCore/Models/ContentItem.swift) data (no network).

### Imported upstream-adjacent surfaces (roadmap tranches)

- **On-device insights:** [`AnalyticsInsightsView`](../ios/Skymarshal/UI/AnalyticsInsightsView.swift) + [`AnalyticsSnapshot`](../ios/SkymarshalCore/Models/AnalyticsSnapshot.swift).
- **Power search:** [`ContentSortOrder`](../ios/SkymarshalCore/Models/ContentSortOrder.swift), [`SavedSearchPresetRecord`](../ios/SkymarshalCore/Storage/StorageModels.swift), [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) ellipsis menu.
- **Advanced keyword grammar (optional):** [`SearchKeywordGrammar`](../ios/SkymarshalCore/Models/SearchKeywordGrammar.swift), [`AdvancedSearchBuilderView`](../ios/Skymarshal/UI/AdvancedSearchBuilderView.swift); default-off flag `sm.feature.advancedSearchGrammar`.
- **Delete preflight:** [`DeletePreflight`](../ios/SkymarshalCore/Services/DeletePreflight.swift) — counts Bluesky records that would be deleted vs. skipped selections; surfaced in bulk delete confirmation.
- **Backup import:** [`ContentBackupImport`](../ios/SkymarshalCore/Services/ContentBackupImport.swift), [`BackupRestoreView`](../ios/Skymarshal/UI/BackupRestoreView.swift); default-off `sm.feature.backupRestore`.
- **Word patterns (optional):** [`WordPatternsService`](../ios/SkymarshalCore/Services/WordPatternsService.swift); default-off `sm.feature.wordPatterns`.
- **Visualization hub (optional):** [`VisualizationHubView`](../ios/Skymarshal/UI/VisualizationHubView.swift), [`GraphSnapshotWriter`](../ios/SkymarshalCore/Services/GraphSnapshotWriter.swift), graph models in [`StorageModels`](../ios/SkymarshalCore/Storage/StorageModels.swift); default-off `sm.feature.visualizationHub`.
- **Cleanup presets:** [`CleanupPreset`](../ios/SkymarshalCore/Models/CleanupPreset.swift) applied to [`FollowerFilters`](../ios/SkymarshalCore/Models/FollowerFilters.swift).
- **Rollout toggles:** [`FeatureFlags`](../ios/SkymarshalCore/Standards/FeatureFlags.swift) (`UserDefaults`; keys `sm.feature.*` and `sm.ui.contentPowerToolsExpanded` — per-key first-launch defaults documented in source).

## Network and storage

- **HTTP:** [`ATProtoClient`](../ios/SkymarshalCore/Network/ATProtoClient.swift) — `URLSession` only, no third-party ATProto SDK; Bluesky hosts `bsky.social` / `public.api.bsky.app`.
- **Session lifecycle:** [`ATProtoClient`](../ios/SkymarshalCore/Network/ATProtoClient.swift) persists the rotating `(accessJwt, refreshJwt)` pair via [`SessionStore`](../ios/SkymarshalCore/Standards/SessionStore.swift) (Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). When an XRPC call returns the structured `ExpiredToken` / `InvalidToken` / `AuthenticationRequired` envelope, `perform(_:)` calls `com.atproto.server.refreshSession`, replays the request once with the new bearer, and posts `Notification.Name.skymarshalSessionInvalidated` if the refresh JWT itself is dead. Concurrent in-flight requests share one refresh via `refreshTask`. `RootView` calls `AppModel.tryRestoreSession()` at cold start so a valid refresh JWT (3-month TTL) skips the LoginView; an invalidated session flips the UI back with a one-shot banner instead of an opaque toast.
- **Persistence:** SwiftData schemas in [`Storage/`](../ios/SkymarshalCore/Storage/StorageModels.swift); per-account isolation via composite keys (see [`AGENTS.md`](../AGENTS.md)).
- **Background tasks:** [`BackgroundTaskCoordinator`](../ios/Skymarshal/App/BackgroundTaskCoordinator.swift) — registers `BGAppRefreshTask` / `BGProcessingTask` and runs bounded [`GraphSnapshotWriter.refreshPersistedSummariesFromCache`](../ios/SkymarshalCore/Services/GraphSnapshotWriter.swift) (SwiftData only; no full archive fetch in background).
- **Rate limits:** [`RateLimit.withBackoff`](../ios/SkymarshalCore/Standards/RateLimit.swift) preserves the Python deletion backoff schedule — do not simplify.

## Standards (non-negotiables)

| Concern | Implementation |
|---------|----------------|
| Status colors | [`Theme`](../ios/SkymarshalCore/Standards/Theme.swift) — no raw `.red` / ad hoc RGB for semantic states. |
| Motion | [`ReduceMotion.shouldReduce`](../ios/SkymarshalCore/Standards/ReduceMotion.swift) at animation sites. |
| Follower automation signals | [`BluescreenAnalyzer`](../ios/SkymarshalCore/Standards/BluescreenAnalyzer.swift). |
| Session tokens | [`SessionStore`](../ios/SkymarshalCore/Standards/SessionStore.swift) — Keychain-only, device-only, never the app password itself. |
| Rate-limit retries | [`RateLimit.withBackoff`](../ios/SkymarshalCore/Standards/RateLimit.swift) (`[1,2,4,8,15,30,60,120]`), separate from the refresh-and-retry path on [`ATProtoClient`](../ios/SkymarshalCore/Network/ATProtoClient.swift). |

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
