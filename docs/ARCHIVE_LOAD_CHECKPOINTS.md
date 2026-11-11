# Archive load checkpoints

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

## Purpose

Large-account `ensureContentLoaded` runs for a long time. If the app is suspended or killed mid-pagination, SwiftData may already contain **partial** pages while the in-memory `loadedContent` snapshot is lost. Checkpoints record the **next XRPC cursor** and **page count** per phase so the next load can resume without duplicating rows (in-memory dedupe by `ContentItem.id`).

## SwiftData model

`ArchiveLoadCheckpointRecord` (see `ios/SkymarshalCore/Storage/StorageModels.swift`):

| Field | Meaning |
|-------|---------|
| `scopeKey` | Unique `"\(ownerHandle)|\(phaseRaw)"` |
| `ownerHandle` | Same owner key used for `ContentItemRecord` rows (`currentHandle` or DID string). |
| `phaseRaw` | `"posts"` (author feed) or `"likes"` (`getActorLikes`). |
| `cursor` | Opaque next-page cursor from Bluesky, or `nil` after a page that ended the feed. |
| `pagesFetched` | Count of pages completed in this phase (for progress continuity). |
| `updatedAt` | Last write time. |

**Invariant:** a row exists **only while a phase is incomplete** (interrupted or mid-flight). When pagination ends with `cursor == nil`, the row is **deleted**. When the user runs **Refresh** (`forceRefresh: true`), all checkpoints and cached content rows for that owner are cleared.

## Wiring

`ContentService.ensureContentLoaded` skips the early “already loaded” return when any checkpoint exists for the active owner so hydration + partial cache can continue into the network loops. `loopEndpoint` reads the starting cursor, appends with dedupe, upserts the checkpoint after each page, and deletes the checkpoint when the phase completes cleanly.

## Future extensions

- Optional **DID-keyed** sidecar if owner display strings ever diverge from persistence keys.
- Background continuation of archive fetch itself (today BG work is graph-summary refresh only).
