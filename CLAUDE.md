# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project intent

The directory is named `skymarshal-ios` but currently holds the upstream **Python codebase** (CLI + Flask/SocketIO web backend + bundled React webapp under `skymarshal-web/`). The iOS port has not started.

The goal of work here is a **focused SwiftUI iOS port** of one slice of Skymarshal: **content management only** — authenticate, search the user's own posts / replies / reposts / likes with highly dynamic filters, and delete them safely. Everything else (firehose, network graphs, bot detection, follower cleanup, analytics, egonet) is **out of scope** unless explicitly requested. Use sister projects `/Users/luke/workspace/alt-text-apple/ios/` and `/Users/luke/workspace/whatcolor/ios/` as the xcodegen + SwiftUI pattern parents.

Note: `CLAUDE.md` is in `.gitignore` — this file is local guidance, not a checked-in artifact.

## What lives here today (the porting source)

```
skymarshal/              # Python package, the actual product
  app.py                 # InteractiveContentManager — Rich-based menu CLI controller
  models.py              # ContentItem, ContentType (POSTS/REPLIES/REPOSTS/LIKES),
                         #   SearchFilters, UserSettings, DeleteMode, console
  auth.py                # AuthManager — atproto Client wrapper, session persistence
  data_manager.py        # CAR download + JSON merge + engagement hydration
  search.py              # SearchManager — keyword/date/engagement/type filtering
  deletion.py            # DeletionManager — 429-aware retry, multi-mode delete
  engagement_cache.py    # SQLite cache, TTL by post age (1h / 6h / 24h / 7d)
  services/content_service.py
                         # **High-level orchestrator** — login / ensure_content_loaded /
                         #   search / delete / summarize. THIS is the surface to port.
  api/                   # Flask blueprints (auth, content, analytics, network,
                         #   profile, cleanup, firehose) — wraps ContentService
  web/                   # Older standalone Flask app (still used)
  egonet/                # Standalone follower-graph viz Flask app
  firehose/, network/, analytics/, cleanup/, followers.py, bot_detection.py
                         # OUT OF SCOPE for the iOS port

skymarshal-web/          # Separate React/TypeScript/Vite client (own README,
                         # own package.json, deployed at skymarshal.blue).
                         # OUT OF SCOPE — do not modify unless asked.

unified_app.py           # Entry: `python unified_app.py` runs Flask + SocketIO
                         # behind a /skymarshal URL prefix
loners/                  # Older standalone scripts (analyze, delete, search…) —
                         # historical, mostly superseded by skymarshal/
tests/unit/              # pytest suite, fixtures in tests/fixtures/
```

## Architectural facts that span files

1. **`ContentService` is the porting boundary.** `skymarshal/services/content_service.py` exposes `login() / ensure_content_loaded() / search(SearchRequest) / delete(uris) / summarize()`. The Flask blueprints, the CLI app, and (eventually) the iOS app should all sit on top of this same surface. When porting to Swift, mirror this API shape — don't re-translate `app.py`'s menu code.
2. **Two data paths, CAR-first by default.** `ContentService.ensure_content_loaded()` tries `_export_via_backup` (single CAR download — fast for large accounts) before `_export_via_api` (paginated, slower, gets engagement inline). Toggle via `SKYMARSHAL_USE_CAR=0`. The iOS port should default to API-paginated since CAR decode requires `libipld`/`cbor2` and is awkward on iOS.
3. **Engagement scoring is cached at two layers.** `calculate_engagement_score(likes, reposts, replies)` is `lru_cache`-memoized (weights: 1× likes + 2× reposts + 2.5× replies). On top, `EngagementCache` is a SQLite store keyed by URI with age-tiered TTLs (recent posts re-fetched hourly, archival posts cached 7 days).
4. **Deletion has hard-won 429 handling.** `skymarshal/deletion.py` wraps every `delete_record` call in `_retry_on_rate_limit` with backoff `1s → 2s → 4s → 8s → 15s → 30s → 60s → 120s`. Bluesky's PDS limit is ~5,000 writes/hour/account; a nuke on a 50k-post account will hit it. The iOS port **must preserve this backoff** — don't simplify it away.
5. **User isolation is by handle.** Storage is `~/.skymarshal/{cars,json,backups}/<handle>/…`; settings live in `~/.car_inspector_settings.json`; session cache at `~/.skymarshal/session.json`. iOS equivalent should use the app group container keyed by handle.
6. **Flask app is mounted under `/skymarshal` prefix.** `PrefixMiddleware` in `skymarshal/api/__init__.py` rewrites `SCRIPT_NAME` for reverse-proxy deployment. Local dev URLs need `/skymarshal/api/...`, not bare `/api/...`.
7. **Per-session `ContentService` pool capped at 50.** `_services` dict in `skymarshal/api/__init__.py` evicts oldest on overflow. Don't unbound it — was a memory leak source.

## Commands

```bash
# CLI (Rich-based interactive menus, the original product)
make run                 # python -m skymarshal
skymarshal               # if entry point is on PATH

# Unified Flask + SocketIO backend (powers skymarshal-web React client)
./start.sh               # production, port 5050
PORT=5090 ./start.sh     # dev
python unified_app.py --port 5090 --debug
gunicorn -k eventlet -w 1 unified_app:app   # production-correct (Werkzeug
                                            # is gated on --debug)

# Tests / lint / format
make test                # pytest
pytest tests/unit/test_content_service.py -k login   # single test
make lint                # flake8 + mypy
make format              # black + isort
make check-all           # format + lint + test

# Distribution
make build               # python -m build → dist/
make publish-test        # twine to TestPyPI
make publish             # twine to PyPI
```

Python 3.9+. Install with `pip install -e ".[dev]"`. The `egonet` UI is a separate Flask app at `skymarshal/egonet/app.py` and binds to `127.0.0.1` only (do not change without reading its security note).

## Gotchas worth knowing before you touch the code

- **`ContentType.COMMENTS` exists in `models.py` but is unused.** AT Protocol calls them "replies" (the field on `app.bsky.feed.post`). Use `ContentType.REPLIES`. The iOS UI should also say "replies."
- **CAR decoding has a three-deep fallback chain** in `data_manager.py` (`libipld → atproto_core.cbor → cbor2`). If you see CBOR errors, that chain is the suspect.
- **`atproto<0.1`, `httpx<0.28.0`, `flask<4.0`, `werkzeug<4.0` are pinned** in `pyproject.toml` for a reason — the next atproto minor that nudges httpx past 0.28 was breaking installs.
- **`Console` is initialized with `force_terminal=False` when stdout isn't a tty** so Rich doesn't crash inside Flask. Use `safe_progress()` from `models.py` (not `Progress` directly) when code paths might run under the web backend.
- **Session pool eviction is FIFO not LRU** — fine in practice but don't be surprised by it.

## iOS port — shipped and live in TestFlight

The iOS app at `ios/` is built and pre-TestFlight as of v1.0.0 (build 2). Architecture:

- **xcodegen-driven** — `ios/project.yml` is canonical; `Skymarshal.xcodeproj` regenerates from it. Never edit the xcodeproj directly.
- **Two-target framework split** — `SkymarshalCore` (framework, all models / services / standards / network / storage, no SwiftUI), `Skymarshal` (app, SwiftUI views + AppModel observer).
- **iOS 17+ floor** — `@Observable`, SwiftData, modern `.searchable`, `.contentMargins` all required. iOS 26 Liquid Glass is intentional system rendering (TabView floats as a pill) — lean in, don't override.
- **AT Protocol over plain `URLSession`** — `ATProtoClient` wraps `bsky.social/xrpc/...` + `public.api.bsky.app/xrpc/...`. No third-party Swift SDK. Zero SPM dependencies.
- **Per-handle SwiftData isolation** — `AnalyzedAccountRecord.compositeKey = "<owner>|<did>"` for unique constraints. `ModelContext`-per-call pattern (actor-safe).
- **429 backoff `[1, 2, 4, 8, 15, 30, 60, 120]`** lives in `RateLimit.withBackoff` and is sacred. Never simplify.
- **Engagement weights `1×L + 2×R + 2.5×Reply`** — Python-derived, NOT the TS web's `1/2/3`. Match Python.
- **Bot scoring** — `BluescreenAnalyzer` produces a 0–1 score plus an array of human-readable `botFlags`. The user-facing surface says "automation signals" / "Patterns we noticed" (dignity rename); internals keep "bot". `AnalyzedAccount.userWhitelisted` is the per-account override that exempts the account from the `showBots` filter regardless of score.
- **Keychain for session tokens**; never persist passwords. App passwords (not main) are surfaced in the LoginView copy.
- **CAR decoding skipped on iOS** — paginated API is fine for the MVP, avoids libipld.

## Visual standards (iOS port)

These are load-bearing across every SwiftUI view and easy to break by accident. Audit any new view against this list.

- **`Theme` tokens are the single source of status colors.** `Theme.danger / .caution / .warn / .scope / .success / .info / .like` (defined in `SkymarshalCore/Standards/Theme.swift`) via `UIColor(dynamicProvider:)` so light/dark variants clear WCAG 1.4.11 ≥3:1 against `systemBackground`. Never write `.red` / `.orange` / `.yellow` / raw RGB literals — they fail contrast in one mode or the other.
- **`ReduceMotion.shouldReduce(systemReduceMotion:)` is the single helper** every animation site routes through. ORs the system `accessibilityReduceMotion` env value with the user's `@AppStorage("sm.reduceMotionOverride")` toggle. Pattern: `private var reduceMotion: Bool { ReduceMotion.shouldReduce(systemReduceMotion: systemReduceMotion) }`.
- **Menu trigger labels are icon + short word only.** Verbose dynamic text ("Sort: Followers", "Bots: Balanced") wraps inside iOS 26's circular Menu shape on real device. Current state goes in the Picker dropdown's checkmark, not the trigger label. `.accessibilityLabel` on the Menu carries the full meaning for VoiceOver.
- **SF Symbols on tinted chip backgrounds get `.symbolRenderingMode(.monochrome)`** — iOS 26's dynamic color system auto-selects fallbacks that render mid-size symbols as emoji-like glyphs without an explicit rendering mode.
- **Horizontal ScrollView overflow indicator: `.contentMargins(.trailing, 24, for: .scrollContent)`** — gives the last item a deliberate ~24pt gutter so it rests with a visible "more on the right" affordance instead of being cut mid-character. Mirrors Apple Mail's category-row treatment. Incompatible with `.scrollClipDisabled()` — pick one.
- **iOS 26 Liquid Glass is intentional on TabView.** The floating pill tab bar at the bottom is system rendering when running on iOS 26 even with iOS 17 deployment target. Do NOT apply `.glassEffect()` to list rows / count pills — Liquid Glass is exclusively for the navigation layer.
- **Row min-height ≥ 44pt** on ContentRow + AccountRow (Apple HIG floor). Bio + bot badge dense rows justify 56–60pt; this is a v1.0.1 polish item.
- **Destructive actions ≥ 100 items go through `TypedConfirmSheet`** (`Skymarshal/UI/TypedConfirmSheet.swift`) — explicit "DELETE" typed-confirm gate. Smaller batches use the standard `confirmationDialog`. The metaphor-heavy delete message ("leaves the building") was retired in favor of literal copy.
- **Brand voice**: "Air-traffic control for your Bluesky" — spy-bird AppIcon + dot-matrix LoginView header + scope motif. Never replace.
- **Out of scope unless asked**: firehose, network graphs, bot detection beyond Bluescreen's existing scoring, follower cleanup beyond the existing surface, sentiment scoring, analytics dashboards, content sharing.

## Marketing copy rules (apply to App Store listing too)

- Never use "AI", "AI-powered", "AI-enhanced", "AI-driven". If LLM features ever land, say "the on-device language model" or name the model.
- Don't reference internal tooling (skill names, agent names, "humanize", `/team`, etc.) in any user-facing prose, README, changelog, or release note.
- Author is Luke Steuber. Do not add `Co-Authored-By` to git commits.
