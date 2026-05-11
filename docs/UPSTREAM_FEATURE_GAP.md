# Upstream vs iOS — scope map

This document compares **upstream Skymarshal** (Python CLI, Flask API, React web client, npm toolkit) to the **native iOS app** in this repository.

**It is a scope map and parity checklist, not an implicit roadmap.** Items marked **Non-goal** align with [`PROJECT_PLAN.md`](../PROJECT_PLAN.md). Only rows marked **Future** are candidates for intentional work.

**Portable provenance:** Commits and lift paths are recorded in [`MIGRATION.md`](../MIGRATION.md) (public repos [`lukeslp/skymarshal`](https://github.com/lukeslp/skymarshal), [`lukeslp/skymarshal-web`](https://github.com/lukeslp/skymarshal-web)). Local deploy trees (e.g. `~/servers/skymarshal` on a dev machine) should match those repos but are not authoritative.

---

## Legend

| Label | Meaning |
|-------|---------|
| **In iOS** | Shipped in this repo under [`ios/`](../ios/) |
| **Partial** | Similar behavior; different depth or UX |
| **Non-goal** | Out of scope for the native product unless [`PROJECT_PLAN.md`](../PROJECT_PLAN.md) changes |
| **Future** | Explicitly open for discussion (keep sparse) |

---

## What shipped in iOS (anchors)

| Capability | Code anchor |
|------------|-------------|
| Auth (app password → session) | [`ContentService`](../ios/SkymarshalCore/Services/ContentService.swift), [`ATProtoClient`](../ios/SkymarshalCore/Network/ATProtoClient.swift) |
| Load own archive (API pagination; no CAR) | `ContentService.ensureContentLoaded` |
| Search / filter / summarize counts | `ContentService.search`, `summarize` |
| Delete with 429 backoff | `ContentService.delete`, [`RateLimit`](../ios/SkymarshalCore/Standards/RateLimit.swift) |
| Export JSON/CSV (share sheet) | [`Exporter`](../ios/SkymarshalCore/Standards/Exporter.swift) |
| Follower scan + Bluescreen scoring + filters + bulk unfollow | [`FollowerService`](../ios/SkymarshalCore/Services/FollowerService.swift), [`BluescreenAnalyzer`](../ios/SkymarshalCore/Standards/BluescreenAnalyzer.swift) |
| Interaction history (per account) | [`InteractionService`](../ios/SkymarshalCore/Services/InteractionService.swift), sheet from follower UI |
| On-device archive insights (histograms, hours, top words) | [`AnalyticsService`](../ios/SkymarshalCore/Services/AnalyticsService.swift), [`AnalyticsInsightsView`](../ios/Skymarshal/UI/AnalyticsInsightsView.swift) |
| Saved search presets + list sort | [`SavedSearchPresetRecord`](../ios/SkymarshalCore/Storage/StorageModels.swift), [`ContentSortOrder`](../ios/SkymarshalCore/Models/ContentSortOrder.swift), [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) |
| Follower cleanup presets + unfollow dry-run | [`CleanupPreset`](../ios/SkymarshalCore/Models/CleanupPreset.swift), [`BluescreenView`](../ios/Skymarshal/UI/BluescreenView.swift) |
| Profile graph explorer (followers/following lists) | [`ProfileService`](../ios/SkymarshalCore/Services/ProfileService.swift), [`ProfileExplorerView`](../ios/Skymarshal/UI/ProfileExplorerView.swift) |

---

## Python CLI (`skymarshal` — Rich menus, `app.py` / `ui.py`)

Upstream exposes a full terminal product: main menu (search, stats, data, auth, followers, settings, help), file-backed workflows, and Rich-only UX.

| Feature | Disposition | Notes |
|---------|-------------|--------|
| Search + refine + export + delete from results | Partial | iOS: [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) — saved presets, sort, quick stats; no Rich legend/pagination idioms |
| Dedicated “statistics / engagement insights” console | Partial | iOS: **Insights** sheet + strip counts — local analytics only; no Rich console tables |
| Data management: multi-file picker, JSON vs backup scenarios | Non-goal | iOS uses SwiftData + single-owner archive load |
| CAR download / import / process / backup-first pipeline | Non-goal | [`PROJECT_PLAN.md`](../PROJECT_PLAN.md) — API path only on device |
| Download via API with limit, date range, categories (desktop export files) | Partial | iOS loads paginated feeds into cache; different export destination (share sheet vs `~/skymarshal`) |
| Refresh / hydrate engagement on loaded files | Partial | Engagement refresh behavior differs; parity rules in [`MIGRATION.md`](../MIGRATION.md) |
| `DeleteMode`: dry-run for **content** deletes | Partial | [`DeleteMode`](../ios/SkymarshalCore/Models/ContentType.swift) exists; content UI still no dry-run — **unfollow** dry-run exists on Followers tab |
| Settings manager (Rich) | Partial | iOS: Keychain + [`AppStorage`](../ios/Skymarshal/UI/AboutView.swift) where applicable |
| Integrated help system | Non-goal | iOS: About / copy; not an interactive help browser |
| Follower submenu “rank / bots / quality” taxonomy | Partial | iOS: BluescreenView filters + sort; not identical menu structure |
| `handle_nuke` / bulk destroy flows | Non-goal | iOS: bulk delete + confirmations; no dedicated “nuke” surface |
| `loners/` standalone scripts (`analyze`, `nuke`, `find_bots`, …) | Non-goal | CLI tooling only |

---

## Flask API (`skymarshal/api/`)

The unified server wraps managers for a **browser client**. The iOS app calls **Bluesky XRPC directly**, not these routes.

| Area | Disposition | Notes |
|------|-------------|--------|
| `/api/auth/*` | Partial | Same auth idea; iOS has no session cookie to Flask |
| `/api/content/search`, delete, CSV export, load, summary | In iOS / Partial | Implemented via `ContentService`; no server-mediated export path |
| `/api/content/export/car` | Non-goal | CAR |
| `/api/content/share`, hosted permalink DB | Non-goal | Server-side sharing; iOS uses local export/share |
| `/api/analytics/*` (sentiment, time patterns, words, insights, …) | Partial | Server sentiment/network analytics remain non-goals; **local** histograms / hours / top words ship via [`AnalyticsService`](../ios/SkymarshalCore/Services/AnalyticsService.swift) |
| `/api/firehose/*` + SocketIO stream | Non-goal | Jetstream / live firehose |
| `/api/network/*` (async graph jobs, cache) | Non-goal | Network graphs |
| `/api/cleanup/*` | Partial | Unfollow/analyze concepts overlap follower tab; no Flask-mediated cleanup |
| `/api/profile/*` (arbitrary handle browsing, bot-check HTTP) | Partial | [`ProfileExplorerView`](../ios/Skymarshal/UI/ProfileExplorerView.swift) adds followers/following lists; still no generic profile browser beyond explorer |

---

## `skymarshal-web` (React client)

| Feature class | Disposition | Notes |
|---------------|-------------|--------|
| Full social client (Home, Discover, Feeds, Thread, Compose, Notifications, Bookmarks, Lists, Chat, Profile, …) | Non-goal | iOS is not a Bluesky client |
| Dedicated Analytics / Firehose / Visualize / Data pages | Non-goal | Power tools live in native slices only |
| Login/session against Skymarshal backend | Non-goal | iOS session is ATProto + Keychain |

---

## `skymarshal-core` (npm package)

Broad JS/TS toolkit (DMs, notifications, feeds product surface, media uploads, network APIs, etc.).

| Disposition | Notes |
|-------------|--------|
| Non-goal | Out of scope unless [`PROJECT_PLAN.md`](../PROJECT_PLAN.md) explicitly expands |

---

## Other upstream surfaces

| Surface | Disposition | Notes |
|---------|-------------|--------|
| `skymarshal/egonet/` (follower graph Flask app) | Non-goal | Visualization server |
| `skymarshal/firehose/` (sentiment, Jetstream helpers) | Non-goal | Firehose / server analytics |
| `skymarshal/network/` | Non-goal | Graph jobs |
| `unified_app.py` + SocketIO hosting | Non-goal | No paired server in iOS app |
| PyPI / systemd / Makefile distribution | Non-goal | iOS uses Xcode / TestFlight |

---

## Maintenance

Update this file when:

1. **Upstream** adds a major subsystem you care to track (new blueprint, new CLI menu).
2. **iOS** adds a major user-facing surface (new tab, new service actor, new export class).

Frozen reference code for diffing behavior: [`reference/README.md`](../reference/README.md).
