# Cold-launch performance — signposts, measurement, observation graph

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**Date:** 2026-05-15  
**Scope:** iOS app cold launch + tab switching (user-reported freeze locus).  
**Code:** [`ColdLaunchSignposts.swift`](../ios/Skymarshal/Profiling/ColdLaunchSignposts.swift), [`AppModel.swift`](../ios/Skymarshal/UI/AppModel.swift), [`RootView.swift`](../ios/Skymarshal/UI/RootView.swift).

---

## 1. What we instrumented (Points of Interest)

Subsystem: **`blue.skymarshal.ios`** · Category: **`ColdLaunch`**

| Signpost / event | Type | Where | Purpose |
|------------------|------|-------|---------|
| `app_init_entry` | event | `SkymarshalApp.init` | First line of app init |
| `app_init_exit` | event | `SkymarshalApp.init` | After `BackgroundTaskCoordinator.register()` |
| `live_default_total` | interval | `AppModel.liveDefault()` | Full construction of container + services |
| `model_container_open` | interval | nested in `live_default_total` | `SkymarshalSchema.makeContainer()` |
| `root_cold_start_task` | interval | `RootView.task` | `hydrateFromCache` + `tryRestoreSession` + seeds + BG scheduling |
| `hydrate_from_cache` | interval | `AppModel.hydrateFromCache()` | SwiftData fetch + map + assign `items` / `accounts` |
| `session_restore` | interval | `AppModel.tryRestoreSession()` | Actor hop + `ATProtoClient` / Keychain resume |
| `tab_content_appear` | event | `ContentListView.onAppear` | Proxy for Content tab selection / first paint |
| `tab_followers_appear` | event | `BluescreenView.onAppear` | Followers tab |
| `tab_scope_appear` | event | `VisualizationHubView.onAppear` | Scope tab |

**How to capture (local):** Xcode → Product → Profile → choose **Time Profiler** or **SwiftUI** (Xcode 15+) and enable **Points of Interest** for the process, or use the **os_signpost** lane. Filter subsystem `blue.skymarshal.ios`. Record a launch, then switch Content → Followers → Scope and compare wall time between `root_cold_start_task` end and first `tab_*_appear` after user-driven tab change.

> **Note:** This workspace run did not attach a saved `.trace` bundle (CI/sandbox). The ranking below combines **static analysis** + **one XCTest wall-clock micro-benchmark** for the hydration SQL path.

---

## 2. Ranked main-thread risk factors (expected “hang” sources)

| Rank | Source | Mechanism | Severity | Evidence |
|------|--------|-----------|----------|----------|
| 1 | **`hydrate_from_cache` + assigning `items` / `accounts`** | Unbounded `FetchDescriptor` for all `ContentItemRecord` / `AnalyzedAccountRecord`, then `filter` by `ownerHandle` in memory, then `map` to domain structs, then assign large arrays on `@MainActor` | **High** at 5k–50k rows | [`AppModel.hydrateFromCache`](../ios/Skymarshal/UI/AppModel.swift) |
| 2 | **`ContentListView` / `BluescreenView` derived lists** | `filteredItems` = filter + **sort** every `body`; `filteredAverageEngagement` O(n); `allFilteredSelected` builds `Set` from full filtered list | **High** when `items` large + any `model` field invalidates body | [`ContentListView.swift`](../ios/Skymarshal/UI/ContentListView.swift) |
| 3 | **`live_default_total` / `model_container_open`** | First SQLite open + migration / recovery can stall main thread | **Medium** (spiky on first install / recovery) | CoreSimulator log showed store recovery during test run |
| 4 | **`session_restore`** | Keychain read + network refresh on cold path (actor hops) | **Medium** (network-bound; can feel like “freeze” if UI waits) | [`ContentService.tryRestoreSession`](../ios/SkymarshalCore/Services/ContentService.swift) |
| 5 | **Tab switch** | SwiftUI re-renders inactive tab; recomputes **#2** for visible tab | **Medium** | `tab_*_appear` events |

### XCTest micro-benchmark (in-memory, 400 `ContentItemRecord`)

Test: [`ColdLaunchHydrationPatternTests`](../ios/SkymarshalTests/ColdLaunchHydrationPatternTests.swift) — mirrors fetch + `filter` pattern.

- **Wall-clock average (simulator sample):** ~**0.007 s** per iteration (400 rows).  
- **Interpretation:** Small DB is fine; **scaling is linear** in row count — 10k+ rows on device + disk I/O + mapping to `ContentItem` will dominate cold launch.

---

## 3. Appendix A — `@Observable` / `AppModel` observation graph

Any write to an observed property on `AppModel` invalidates SwiftUI bodies that **read** that property (or coarser-grained invalidation depending on Observation implementation). Compounding reads in one `body` tie unrelated updates together.

| View | Reads (representative) | Invalidates heavily when… |
|------|-------------------------|----------------------------|
| `RootView` | `isAuthenticated`, `accounts`, `items` | Hydration, login, logout, session expiry |
| `ContentListView` | `items`, `summary`, `loadProgress`, `isLoading`, `currentHandle`, `lastContentScannedAt`, `deleteInterruptionNotice` | **Every** `loadProgress` tick during scan; hydration |
| `BluescreenView` | `accounts`, `scanSummary`, `scanProgress`, `isScanning`, `errorMessage`, `lastFollowerScannedAt` | Scan progress updates |
| `LoginView` | `isLoading`, `errorMessage`, `sessionExpiredNotice` | Auth + errors |
| `VisualizationHubView` + nested viz | `accounts`, `items`, `graphSnapshotSummaries` | Graph refresh / hydration |
| `BackupRestoreView` | `isAuthenticated`, `currentHandle`, `currentDid`, `items` | Hydration |
| `AccountDetailView` | `followers` (service), `model` for whitelist | Less churn |
| `InteractionHistoryView` | `items`, `accounts`, `content` | Large arrays |
| `ProfileExplorerView` | via `model.loadExplorer*` | Less on cold path |

**Churn pattern:** `runLoad` assigns `loadProgress`, `items`, and `summary` together on `MainActor` ([`AppModel.runLoad`](../ios/Skymarshal/UI/AppModel.swift)) — any view reading `items` **and** `loadProgress` will re-run `filteredItems` (O(n log n)) on **every** progress callback.

---

## 4. Next engineering actions (not executed in this doc)

1. Predicate-scoped fetch for `ownerHandle` + optional `@Index` on `ownerHandle` (schema).  
2. Cache `filteredItems` / debounce search; avoid full-list sort in `body`.  
3. Split observation domains (`ContentUIModel` vs `FollowersUIModel`) or pass lightweight snapshots into list rows.  
4. Profile on **physical device** with a large real cache — simulator numbers are not authoritative.
