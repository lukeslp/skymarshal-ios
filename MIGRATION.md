# Migration provenance

This repo is a fresh start. The Python and TypeScript material under `reference/`
was lifted on **2026-05-09** from these source commits:

- **Python skymarshal CLI/Flask:** `lukeslp/skymarshal` @ `53a7ea087e303fe4ec772e19ed67b5067fe5ebbe`
  (public repo at https://github.com/lukeslp/skymarshal — left untouched, still the active
  line for the Python product)
- **TypeScript skymarshal-web:** `lukeslp/skymarshal-web` @ `7e70fd97cd413cab089357ee4e4e5e91e0501687`
  (a separately-cloned repo at the time of lift)

## Why fresh, not branched

The new product is a focused SwiftUI iOS app for Bluesky content management
(search + delete own posts, replies, reposts, and likes). The upstream
codebases include 6+ subsystems out of scope (firehose, network graphs,
follower cleanup, analytics, Flask API, tRPC routers). Branching would carry
that conceptual drag into every iOS pull request. A fresh init keeps the
active codebase scoped, and the reference/ tree preserves the porting source.

Branch-vs-fresh tradeoffs were independently validated by external models
(Gemini and Codex). Both recommended fresh + reference for this scope. See
`~/.swarm/reports/2026-05-09/begin-skymarshal-ios.md` and
`~/.swarm/reports/2026-05-09/enhance-skymarshal-ios.md` for full analysis.

## What was intentionally excluded

For the full keep / drop inventory, see
`~/.swarm/reports/2026-05-09/janitor-skymarshal-ios.md`.

Out of scope (not in `reference/`):
- `loners/` — pre-skymarshal standalone scripts
- `skymarshal/{firehose,network,egonet,cleanup,analytics,api,web}/` — subsystems
  unrelated to content management
- `skymarshal/{bot_detection.py,followers.py}` — follower analysis features
- `skymarshal-web/{server,drizzle,data,scheduler}/` — Express + Drizzle backend
- Most of `skymarshal-web/client/src/pages/` (Analytics, Bookmarks, Chat,
  Compose, Discover, Feeds, FeedView, Firehose, Home, Lists, Notifications,
  Profile, Scheduled, Settings, Thread, Visualize)
- Build infrastructure (`Makefile`, `pyproject.toml`, `requirements*.txt`,
  `vite.config.ts`, `pnpm-lock.yaml`, etc.)
- Test suites — the iOS port uses XCTest fresh, not pytest/vitest

## Drift to be careful of (TS port deviated from Python — preserve Python where they disagree)

The TypeScript managers in `reference/web/skymarshal/` are the **structural**
porting reference (six-manager facade, IndexedDB schema, TypeScript-to-Swift is
near-mechanical). But on three load-bearing pieces, the TS port drifted from
the Python source. The Swift port should follow Python:

1. **429 backoff schedule:** TS `DeletionManager.deleteFromRemote` is a single
   fetch with no retry loop. The Python `deletion.py:31-70` schedule
   `(1, 2, 4, 8, 15, 30, 60, 120)` seconds is the proven behavior. **Lift
   verbatim into Swift `RateLimit.swift`.**
2. **Engagement weights:** TS `enums.ts` uses `{likes: 1, reposts: 2, replies: 3}`.
   Python `models.py:51-60` uses `1×likes + 2×reposts + 2.5×replies`. Use
   **Python's 2.5 reply weight** — the rationale (replies require the most
   effort but the float weight prevents thread blowups from dominating) is
   documented in the Python file's docstring.
3. **SearchFilters:** TS `types.ts` adds `authorDid`, `excludedUris`,
   `minEngagement`, `maxEngagement` that Python lacks. These are good
   additions; **adopt them in Swift `SearchRequest`**.

Also intentionally dropped on iOS:

- **CAR-file processing.** Requires `libipld`/`cbor2` on the server side.
  The TS port already stubs CAR ops as Phase 2 errors. Swift port goes
  API-paginated only.

## Lift map (pre-wipe path → reference path)

| Source path | New location |
|---|---|
| `skymarshal/deletion.py` | `reference/python/deletion.py` |
| `skymarshal/models.py` | `reference/python/models.py` |
| `skymarshal/auth.py` | `reference/python/auth.py` |
| `skymarshal/search.py` | `reference/python/search.py` |
| `skymarshal/engagement_cache.py` | `reference/python/engagement_cache.py` |
| `skymarshal/data_manager.py` | `reference/python/data_manager.py` |
| `skymarshal/services/` | `reference/python/services/` |
| `skymarshal-web/client/src/lib/bluesky/skymarshal/` | `reference/web/skymarshal/` |
| `skymarshal-web/shared/bsky.ts` | `reference/web/bsky.ts` |
| `skymarshal-web/client/src/pages/{Login,Search,ContentManagement,Cleanup,DataManagement}.tsx` | `reference/web/pages/` |
| `README.md` (Python) | `reference/docs/README.md` |
| `ARCHITECTURE.md` | `reference/docs/ARCHITECTURE.md` |
| `API.md` | `reference/docs/API.md` |
| `CHANGELOG.md` | `reference/docs/CHANGELOG.md` |
| `alt-text-apple/ios/project.yml` | `reference/sister-templates/alt-text-apple-project.yml` |
