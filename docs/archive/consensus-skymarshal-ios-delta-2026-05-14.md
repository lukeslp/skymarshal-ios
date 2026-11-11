# Consensus delta — implementation vs 2026-05-13 matrix

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../../README.md).

This note records what shipped after [`consensus-skymarshal-ios-2026-05-13.md`](consensus-skymarshal-ios-2026-05-13.md) so Q4/Q6 readers are not misled by the original “next slice” wording alone.

## Q4 (background refresh / checkpoints)

**Shipped (partial):**

- **Archive load checkpoints** — [`ArchiveLoadCheckpointRecord`](../../ios/SkymarshalCore/Storage/StorageModels.swift) + [`ContentService.ensureContentLoaded`](../../ios/SkymarshalCore/Services/ContentService.swift) resume cursors per owner for posts/likes pagination; cleared on successful phase completion or cache wipe / `replaceAll` import.
- **Background tasks** — [`BackgroundTaskCoordinator`](../../ios/Skymarshal/App/BackgroundTaskCoordinator.swift) registers `BGAppRefreshTask` / `BGProcessingTask` and runs **bounded** [`GraphSnapshotWriter.refreshPersistedSummariesFromCache`](../../ios/SkymarshalCore/Services/GraphSnapshotWriter.swift) (SwiftData only, **no** network archive continuation in background).

**Not shipped (explicit non-goal for this slice):**

- Full **`ensureContentLoaded`** continuation inside background execution (would require session + network policy + UI honesty work).

## Q6 (soak / resume failure modes)

**Shipped:**

- **Delete interruption breadcrumb** — [`DeleteBatchRecovery`](../../ios/SkymarshalCore/Services/DeleteBatchRecovery.swift) + user-visible alert in [`ContentListView`](../../ios/Skymarshal/UI/ContentListView.swift); **no auto-resume** of destructive deletes (intentional safety posture).
- **Soak checklist** — [`docs/SOAK_PROTOCOL.md`](../SOAK_PROTOCOL.md).

## D2 prompt

Re-run Codex / Claude on the canonical prompt when reliability + submission hardening stabilize; append a new dated delta file using this filename pattern.
