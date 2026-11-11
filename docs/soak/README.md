# Soak artifacts

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../../README.md).

Commit soak outputs here before public App Store submission (**kill criterion #1**).

## Required for Run 1 (≥10k-post account)

| Artifact | Filename pattern | Notes |
|----------|------------------|--------|
| Screen recording | `run1-YYYY-MM-DD-screen.mov` | Full session: load → filter → delete batch → export |
| Signpost trace | `run1-YYYY-MM-DD-signposts.trace` | Instruments, subsystem `blue.skymarshal.ios` |
| Observation note | `run1-YYYY-MM-DD-OBSERVATION.md` | Copy from `OBSERVATION_TEMPLATE.md` |

## Three required scenarios (safety committee)

1. **Resume:** Paginated import → kill app at ~50% → relaunch → no duplicate rows.
2. **429:** ≥1000-delete sweep that hits PDS rate limit → backoff recovers; no crash.
3. **JWT:** Force session expiry mid bulk-delete or mid load → graceful re-auth; no delete on stale auth.

## Protocol

Full steps: [../SOAK_PROTOCOL.md](../SOAK_PROTOCOL.md).
