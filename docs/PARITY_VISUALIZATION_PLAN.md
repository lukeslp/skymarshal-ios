# Parity + Visualization Implementation Plan (iOS)

**Status:** In progress — Phases 1–2 largely **shipped** on `main` (2026-05); Phase 3+ remain planning / partial  
**Updated:** 2026-05-13  
**Scope:** Bring upstream CLI/web parity into native iOS where it improves safe cleanup outcomes, plus account/post/interaction visualizations.

## 2026-09-04 Mobile Visual-Parity Directive

The canonical interactive visual surface is the shared web route at
`skymarshal-web/client/src/pages/Visualize.tsx`. Mobile integration preserves
that rendered experience instead of maintaining a second approximation:

- Post interactions, post sentiment, follower network, and community chord stay
  owned by the shared `/visualize` route.
- A fifth **Constellation** mode embeds Jaz's live BSky Atlas at
  `https://bsky.jazco.dev/`. Skymarshal does not copy or redistribute its graph
  snapshot.
- Android exposes `/visualize` from its Capacitor navigation and packages the
  same React implementation.
- The native iOS Scope hub opens the hosted `/visualize` route in an app-bound
  `WKWebView`; native Scope summaries remain available as the local/offline
  alternative.
- No native session token is injected into web content. Authentication and
  storage boundaries remain explicit.

### Intake and delivery tracks

| Platform | Source spine | Current state | Build/validation gate | Device/accessibility gate |
| --- | --- | --- | --- | --- |
| iOS 17+ | Native SwiftUI plus the hosted canonical visual route | scaffolded | XcodeGen build and focused XCUITest | VoiceOver names/order, Dynamic Type, Reduce Motion, rotation |
| Android 7+ | Capacitor-packaged React route | scaffolded | TypeScript, Vitest, Vite/Capacitor sync, Gradle test/lint | TalkBack, 44px targets, rotation/reflow, gesture alternatives |

Store staging and submission are intentionally outside this integration. Track
states advance only with the evidence named above.

## Executive Direction

Ship this as a safety-first expansion, not parity theater.  
Priority order:

1. Trust and safety rails (delete correctness, session integrity, explicit scope)
2. High-value parity (advanced search grammar, review modes, backups)
3. Bounded visual intelligence (graphs + heatmaps with completeness labeling)
4. Productization and hardening (scale, rollout controls, kill gates)

## Four Parallel Tracks

### 1) Core parity migration
- Query grammar parity: `+required`, `-exclude`, quoted phrases, subject filters
- Delete review modes (item-by-item and batch review)
- Scoped collection operations with typed confirms and dry-run first
- Backup/archive lifecycle parity (import, export, restore preview, integrity checks)

### 2) Visualization system
- Account relationship visualization (mutuals, clusters, bridges)
- Post relationship visualization (reply/repost/like paths)
- Interaction timeline heatmaps (hour/day and account slices)
- Completeness-aware graph states (partial vs complete data never conflated)

### 3) UX + information architecture
- Advanced mode IA without harming first-run usability
- Safety-centered destructive flows
- Distinctive "operations console" visual language for graph/analysis surfaces
- Accessibility-first chart/graph equivalents (voice summaries + tabular fallback)

### 4) Reliability, privacy, performance, and test rigor
- Keep sacred 429 backoff and deletion URI semantics
- Local-first data policy and per-handle isolation
- Checkpointed incremental background updates
- Performance budgets + regression gates + release kill criteria

## Phase Plan

### Shipment snapshot (`main`, 2026-05)

**Delivered:** Grammar v1 + tests; `DeletePreflight` + confirmation copy; SwiftData graph schema + `GraphSnapshotWriter`; Visualization Hub alpha (Scope tab, default off); word-pattern lexicon stats (default off); JSON backup import with integrity gate (default off); advanced search builder (default off); `BGAppRefresh` / `BGProcessing` scaffolding via [`BackgroundTaskCoordinator`](../ios/Skymarshal/App/BackgroundTaskCoordinator.swift) (local graph-summary writes, no network); session refresh + Keychain persistence via [`SessionStore`](../ios/SkymarshalCore/Standards/SessionStore.swift) + [`ATProtoClient.refreshSession`](../ios/SkymarshalCore/Network/ATProtoClient.swift). **Partial vs this doc:** “Delete review center” is preflight + typed confirm, not a separate review browser; hub graphs are bounded summaries, not full ego-ring force layout; baseline perf reports against the 10k / 50k fixtures are not yet committed. **Phase 3:** sentiment/correlation analytics and restore-preview diff remain open; import/merge is further along than full CAR center.

## Phase 1 — Foundation + Safety Gates

**Goals**
- Create primitives required by all future parity and visualization work.
- Close trust gaps before feature expansion.

**In scope**
- Query AST v1 and parser tests.
- Destructive preflight model (`exact count`, `record types`, `target handles`).
- Graph storage schema v1 (nodes, edges, checkpoints, completeness flags).
- Session/storage truth audit and correction.
- Baseline perf harness for 10k and 50k record fixtures.

**Out of scope**
- Interactive graph UI.
- CAR import/export UI.
- Sentiment/correlation analytics.

**Dependencies**
- Existing `ContentService`, `FollowerService`, `ATProtoClient`, SwiftData stack.

**Exit criteria**
- Query parse/serialize round-trip succeeds for full grammar v1.
- Preflight always matches final destructive operation set.
- Session persistence behavior documented and implemented consistently.
- Baseline perf report committed to docs.

## Phase 2 — High-Value Parity + Bounded Visuals

**Goals**
- Deliver immediately useful parity while introducing safe, bounded visualization.

**In scope**
- Advanced search grammar UI and execution.
- Delete review center (individual and batch modes).
- Guarded scoped collection operations (flagged rollout).
- Visualization Hub v1:
  - Account graph (ego + mutual rings)
  - Interaction bridge graph
  - Timeline heatmap

**Out of scope**
- Full open-ended force-directed graph for entire social universe.
- One-tap wholesale destructive actions.

**Dependencies**
- Phase 1 query/graph schemas, background coordinator scaffolding.

**Exit criteria**
- Query latency and memory budgets hit on 50k fixture account.
- Graphs always show completeness state and last-updated timestamps.
- Accessibility review passes for chart/graph alternatives.

## Phase 3 — Archive Lifecycle + Advanced Analytics

**Goals**
- Add recovery-grade backup capability and richer decision analytics.

**In scope**
- CAR/backup center v1:
  - Export/import
  - Restore preview diff
  - Integrity checksum validation
- Advanced analytics (flagged):
  - Sentiment summary
  - Word frequency
  - Engagement correlation
- Post graph v1 (content relationship view by URI/account/date slices).

**Out of scope**
- Cloud backup sync.
- Fully automated destructive cleanup.

**Dependencies**
- Stable checkpoints and operation logs from prior phases.

**Exit criteria**
- Backup restore preview correctness proven via fixture tests.
- Advanced analytics include confidence/limitations copy.
- Thermal/perf budget passes on baseline devices.

## Phase 4 — Hardening + Productization

**Goals**
- Ship only features that meet safety, performance, and usage thresholds.

**In scope**
- Progressive rollout + rollback controls by feature flag.
- Operational runbooks and incident playbooks.
- Polishing graph interactions and analysis explainability.
- Optional danger-zone operations only if prior safety gates pass.

**Out of scope**
- New feature families without measurable user value signal.

**Dependencies**
- Metrics from TestFlight cohorts.

**Exit criteria**
- No wrong-target delete defects in RC.
- Core cleanup completion time does not regress.
- Advanced features meet adoption thresholds.

## Visualization Data Architecture (iOS)

## Entities
- `GraphNode`
  - `id`, `did`, `handle`, `nodeType`, `displayName`
  - `freshnessState`, `completenessState`, `lastSyncedAt`
- `GraphEdge`
  - `id`, `sourceDid`, `targetDid`, `edgeType`
  - `weight`, `firstSeenAt`, `lastSeenAt`, `provenance`
- `GraphSnapshot`
  - `ownerDid`, `scope`, `generatedAt`, `completenessSummary`
- `GraphCheckpoint`
  - endpoint cursor and resume metadata per scope.

## Pipeline
1. Endpoint fetch pages
2. Normalize to canonical events
3. Derive edges and aggregate weights
4. Materialize snapshot tables for UI reads
5. Publish partial/completed state explicitly

## Cache strategy
- L1: actor memory cache for active view/session
- L2: SwiftData persisted graph + aggregate snapshots
- Invalidate on destructive writes, owner switch, TTL expiry, schema bumps

## Incremental updates
- `BGAppRefreshTask` for light deltas
- `BGProcessingTask` for heavy recompute
- Checkpoint after each slice to support resumable jobs
- Foreground view can prioritize pending scope updates

## Privacy controls
- Local-first processing and storage
- Explicit export only; optional redaction presets
- Per-handle isolation and one-tap local wipe
- Privacy manifest and required-reason API review every release

## Risk Register + Mitigation

1. **Wrong-target deletion (critical)**  
   Mitigation: immutable preflight, typed confirmation, operation receipt log.
2. **Rate-limit saturation (high)**  
   Mitigation: scheduler with read/write budgets, backoff invariants, queued jobs.
3. **Misleading partial graphs (high)**  
   Mitigation: explicit completeness badges; disable "definitive" labels when partial.
4. **Performance regression on large accounts (high)**  
   Mitigation: node/edge caps, pre-aggregated views, FPS/thermal gates in CI.
5. **Privacy trust erosion (high)**  
   Mitigation: local-only defaults, plain-language data controls, no silent exports.
6. **Feature bloat (medium)**  
   Mitigation: feature flags, quarterly keep/cut review with usage thresholds.
7. **Backup integrity failures (medium)**  
   Mitigation: checksums + restore preview + fixture verification suite.
8. **Accessibility regressions in visualizations (medium)**  
   Mitigation: VO narratives, tabular fallback, contrast and motion audits.

## 90-Day Execution Plan

### Weeks 1-2
- Finalize architecture ADRs (query AST, graph schema, safety gates).
- Implement baseline harnesses and fixture datasets.
- Align docs and implementation truth for session persistence.

### Weeks 3-6
- Ship advanced search grammar v1 behind feature flag.
- Ship delete review center v1 behind feature flag.
- Ship Visualization Hub alpha (account graph + interaction bridge + heatmap).

### Weeks 7-10
- Ship backup/archive center v1 (restore preview + integrity checks).
- Add advanced analytics (sentiment/word/correlation) behind advanced flag.
- Harden operation logs, rollback toggles, and incident playbook.

### Weeks 11-13
- Run rollout drills, perf/thermal sweeps, accessibility regressions.
- Evaluate go/kill thresholds.
- Promote only features that clear safety + value gates.
