# Architectural verdict — cold launch, `@Observable`, SwiftData

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**Date:** 2026-05-15  
**Roles synthesized:** Architect + Greybeard (technical committee).  
**Question:** Did we make an **architectural mistake** tying cold-launch jank to structure?

---

## Decision (one line)

**Not a “wrong stack” mistake — a predictable scale + UI coupling mistake:** one `@MainActor @Observable` hub plus unbounded cache hydration and O(n log n) list derivations on the main thread will freeze as data grows.

---

## Architect — fit with patterns

**Claim:** The port correctly mirrors `ContentService` as the orchestration boundary ([`ContentService.swift`](../ios/SkymarshalCore/Services/ContentService.swift)); UI sits on `AppModel` as adapter — that layering is sound.

**Mechanism:** `AppModel` batches actor calls and exposes plain Swift state for SwiftUI — idiomatic for a small app.

**Risks:** The **adapter grew into a god object** — auth, content snapshots, follower snapshots, graph summaries, presets, and progress flags share one observation graph.

**Evidence:** Single type [`AppModel`](../ios/Skymarshal/UI/AppModel.swift) holds 15+ externally visible properties consumed across 8+ views.

---

## Greybeard — what breaks at 10× data

**Claim:** Cold launch and tab switches are dominated by **main-thread work proportional to row count**, not by URLSession or ATProto design.

**Mechanism:**

1. `hydrateFromCache` fetches **all** rows sorted by `scannedAt`, then filters to one `ownerHandle` in Swift ([`AppModel.hydrateFromCache`](../ios/Skymarshal/UI/AppModel.swift)).
2. `ContentListView.filteredItems` applies filters and **sort** on every body evaluation ([`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift)).
3. `runLoad` updates `items` + `summary` + `loadProgress` together — high-frequency progress → high-frequency full-body recomputation.

**Risks:** Accounts with **tens of thousands** of posts will see multi-hundred ms to multi-second main-thread stalls; tab switch forces sibling tab bodies to reconcile.

**Evidence:** [`docs/PERF_COLDLAUNCH_2026-05-15.md`](PERF_COLDLAUNCH_2026-05-15.md) ranked hotspots + XCTest micro-benchmark for fetch path.

---

## Safety — failure modes if we “fix” wrong

| Quick fix | Failure mode |
|-----------|----------------|
| Move hydration fully off MainActor without care | Race: UI reads `items` before assign completes → empty flash or torn reads |
| Aggressive `@Index` everywhere | Migration cost; still need predicate fetch |
| Split models without updating environment | Duplicate sources of truth for `currentHandle` |

---

## Smallest change set that materially helps (ordered)

1. **Predicate fetch** for latest owner (or cap + “load more”) — drops bytes and object churn from SQLite.  
2. **Memoize / debounce** `filteredItems` — kill repeated sort in `body`.  
3. **Split `AppModel`** into `SessionState` + `ContentListState` + `FollowerListState` (or `@Observable` sub-objects injected separately) — cuts invalidation fan-out.  
4. **Throttle `loadProgress`** updates (e.g. max 4 Hz) during long loads.

---

## Dissent (internal)

**Architect pushback:** Splitting models too early adds navigation / DI complexity before product–market fit — consider **(1)+(2)** first, defer **(3)** until second pain report.

**Greybeard pushback:** Throttling progress alone **masks** symptoms; users still pay full price on first hydration after install.

---

## Verdict table

| Statement | Verdict |
|-----------|---------|
| “We chose the wrong framework (SwiftData / Observation)” | **DISAGREE** |
| “God `AppModel` + unbounded hydration + derived O(n log n) in views is the bottleneck” | **AGREE** |
| “Session restore / Keychain is the dominant cold cost for typical users” | **WAIT** — measure per user (network); often secondary to cache size |
