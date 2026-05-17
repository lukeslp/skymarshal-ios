# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project intent

The repo is now **iOS-first**. The Swift app at `ios/` is shipped to public TestFlight at v1.0.0 / build 5 and is preparing for App Store. The upstream Python CLI and the deployed React web client (`skymarshal.blue`) are no longer co-located here — they sit under `reference/` as snapshots that anchor parity decisions, **not** as runnable code.

Scope: **content management only** — authenticate, search the user's own posts / replies / reposts / likes with highly dynamic filters, delete them safely, plus the Bluescreen follower-scan surface (automation-signal scoring + dry-run unfollow). Everything else from the Python upstream (firehose, network graphs, sentiment, analytics dashboards, egonet, follower cleanup beyond the existing Bluescreen surface) is **out of scope** unless explicitly requested. Sister xcodegen patterns at `reference/sister-templates/` (alt-text-apple) and `/Users/luke/workspace/whatcolor/ios/`.

Note: `CLAUDE.md` is checked in — keep it concise and current. If you want a private scratch file, use `CLAUDE.local.md` (gitignored by convention) instead.

## What lives here today

```
ios/                          # The active product — SwiftUI app, TestFlight v1.0.0/build 5
  project.yml                 # xcodegen canonical source — never edit .xcodeproj directly
  Skymarshal/                 # App target: SwiftUI views, AppModel, App entry
  SkymarshalCore/             # Framework: Models, Services, Standards, Network, Storage
  SkymarshalTests/            # 185 test methods; xcodebuild test green
  SkymarshalUITests/          # UI harness with sm.feature.* flag bridge
docs/                         # iOS-specific planning + design artifacts
  PROJECT_PLAN.md             # (mirror at repo root) — distribution status, council log
  PARITY_VISUALIZATION_PLAN.md, STYLE_RESTYLE_PLAN.md, UPSTREAM_FEATURE_GAP.md
  ARCHITECTURE.md, DESIGN_SYSTEM.md, CONTRIBUTOR_UX.md
  aesthetic-samples/, archive/
app-store/                    # Release pack — screenshots, listing copy, reviewer notes
reference/                    # NOT runnable — anchors parity, ports, and pitch decisions
  python/                     # Python CLI snapshot (auth.py, deletion.py, search.py,
                              #   engagement_cache.py, models.py, services/content_service.py)
                              # — the canonical engagement weights + 429 ladder live here
  web/                        # React/TS client snapshot (skymarshal.blue) —
                              #   pages/{Login,Search,ContentManagement,DataManagement,Cleanup}.tsx,
                              #   skymarshal/{models/enums.ts, managers/SearchManager.ts}
                              # — has an internal engagement-weight split (see Gotchas)
  sister-templates/           # xcodegen patterns from alt-text-apple
  docs/                       # Reference docs from earlier phases
PROJECT_PLAN.md, MIGRATION.md, README.md, AGENTS.md   # Planning artifacts at repo root
```

The Python and React clients here are **read-only references**. To run them, go to their actual repos. Architecture facts below cite `reference/python/...` paths because those are now the on-disk locations of the canonical port targets.

## Architectural facts that span files

1. **`ContentService` is the porting boundary.** `reference/python/services/content_service.py` exposes `login() / ensure_content_loaded() / search(SearchRequest) / delete(uris) / summarize()`. The iOS `SkymarshalCore/Services/ContentService.swift` mirrors this surface and is the dependency root for every view.
2. **iOS uses API-paginated only.** CAR decode requires `libipld` / `cbor2` and is awkward on iOS. Python keeps both paths (CAR-first, API-fallback) — see `reference/python/data_manager.py`. iOS deliberately ships without CAR; documented in `docs/UPSTREAM_FEATURE_GAP.md`.
3. **Engagement weights are `1×L + 2×R + 2.5×Reply` — Python-derived.** Canonical at `reference/python/models.py:52-59` (`calculate_engagement_score`, `lru_cache`-memoized). iOS mirrors at `ios/SkymarshalCore/Models/ContentItem.swift:109-127`. Python also has a SQLite `EngagementCache` (age-tiered TTLs 1h/6h/24h/7d); iOS uses in-memory only. **The web client at `reference/web/` has an internal split:** `skymarshal/models/enums.ts:138-141` declares `replies: 3` and `managers/SearchManager.ts:325-336` uses it for sort/filter, but `pages/ContentManagement.tsx:56` uses `2.5` for display. The web bug is on the web team; iOS stays at 1/2/2.5.
4. **429 backoff is sacred.** Python `reference/python/deletion.py` and iOS `SkymarshalCore/Standards/RateLimit.swift` both use `[1, 2, 4, 8, 15, 30, 60, 120]` seconds. Bluesky PDS limit is ~5,000 writes/hour/account; a 50k-post nuke is wall-clock-bound at ~10 hours minimum *before* 429s. **Never simplify the ladder.**
5. **Per-handle isolation.** Python stores under `~/.skymarshal/{cars,json,backups}/<handle>/…`. iOS uses SwiftData with `AnalyzedAccountRecord.compositeKey = "<owner>|<did>"` as the unique-constraint key and `ModelContext`-per-call for actor safety.

## Commands

```bash
# iOS — the active product
cd ios
xcodegen generate                  # regenerate Skymarshal.xcodeproj from project.yml
xcodebuild -scheme Skymarshal -destination 'platform=iOS Simulator,name=iPhone 15' test
xcodebuild -scheme Skymarshal -destination 'generic/platform=iOS' archive -archivePath build/Skymarshal.xcarchive

# Feature-flag toggles for UITest / dev runs
# Pass via scheme arguments: -sm.feature.advancedSearch YES, -sm.feature.visualizationHub YES, etc.

# Reference snapshots (NOT runnable from this repo — the canonical clients live elsewhere)
# reference/python/ — copy into a real Python project to run
# reference/web/    — copy into a real Vite project to run
```

## Gotchas worth knowing before you touch the code

- **iOS uses `ContentType.REPLIES`, not `.COMMENTS`.** AT Protocol calls them "replies" (the field on `app.bsky.feed.post`). Python `reference/python/models.py` still has a `COMMENTS` legacy value; iOS does not carry it forward.
- **Web client engagement-weight split** — when reading `reference/web/` for parity, note `skymarshal/models/enums.ts:138-141` says `replies: 3` and `SearchManager.ts:336` honors it, but `pages/ContentManagement.tsx:56` uses `2.5`. iOS sides with Python (2.5). The web bug is on the web team — don't propagate the 3 into iOS.
- **Resumable-delete breadcrumb is half-built** — `SkymarshalCore/Services/DeleteBatchRecovery.swift:22-30` writes the full intended-IDs list once at delete-start and never updates per-success. `ContentService.swift:289-318` does the serial delete loop. On mid-batch crash, recovery reports *all* items as pending. Fix is ~5 LOC inside the for-loop (write back after `deleted += 1`). Treat as a ship-blocker for v1.0.x.
- **`ratelimit-reset` / `Retry-After` headers are discarded.** `ATProtoClient.swift:453-466` (`performRaw`) drops response headers; `RateLimit.withBackoff` only uses the fixed `[1,2,4,8,15,30,60,120]` ladder. Worth threading an optional server-supplied wait into `RateLimit` and falling back to the ladder — pattern ported from ATProtoKit's `ATAPIError.tooManyRequests(retryAfter:)`.
- **JWT pre-expiry refresh isn't done.** `ATProtoClient.swift` refreshes reactively on 401. ATProtoKit's `ensureValidToken()` decodes the JWT `exp` claim and refreshes if `<= now + 10s`. One fewer round-trip per stale-token call — file under "convention worth borrowing from ATProtoKit without taking the dep."
- **UTF-8 byte-offset facet parsing trap.** AT Proto facet `byteStart` / `byteEnd` are UTF-8 byte indices. When post bodies eventually render tappable mentions/links, `NSRange` / `String.Index` math will silently corrupt offsets on any emoji or non-ASCII character. Use `text.utf8.distance(...)` with `samePosition(in: text.utf8)`.
- **No-SPM-deps stance is sustainable for ~8 endpoints**, not forever. Trigger to adopt ATProtoKit (or similar): (a) rich-text facet emission for posting, or (b) lexicon drift outpacing hand-rolled `ATProtoTypes.swift`. Neither is in the v1.x brief.

## iOS port — public TestFlight, App-Store-bound

The iOS app at `ios/` is on public TestFlight at v1.0.0 / build 5. Marketing version was briefly tagged 1.0.1 during the visual-restyle work; reverted at commit `9ca2e84` so build 5 carries 1.0.0. Architecture:

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

## Competitive landscape (scout snapshot, useful for App Store positioning)

- **No iOS-native competitor** in the Bluesky content-cleanup category as of May 2026. Direct competitors are web-only: [BskyDelete](https://bskydelete.com) (free, open source, browser-local tokens), [Redact](https://redact.dev/services/bluesky) (freemium, multi-platform), [Bluesky Repo Explorer](https://romiojoseph.github.io/bluesky/bluesky-repo-explorer/) (free, GitHub Pages), [Circleboom](https://circleboom.com) (paid suite).
- **iOS Bluesky clients exist but are feed-readers, not cleanup tools**: the official app, Graysky, Skeets, Croissant. Skymarshal occupies a different shelf.
- **Twitter/X analog pricing band** for "delete your posts" prosumer apps: $4–15/mo or $14.99 one-time (TweetDelete.net is the closest one-time reference).
- **Bluesky 2026 roadmap signals**: no native bulk-delete in the Jan 2026 "What's Next" post. "Deeper third-party app support" is mildly positive signal. Treat as a *signal* not a moat — the lane is open partly because Apple review risk is real and Bluesky may eventually ship this themselves.
- **Swift AT Protocol SDKs exist** ([ATProtoKit](https://github.com/MasterJ93/ATProtoKit), [swift-atproto](https://swiftpackageindex.com/andooown/swift-atproto)). Skymarshal intentionally avoids them — see "no-SPM-deps" gotcha for the adoption trigger.

## Council pre-ship checklist (v1.0.x → App Store)

Action items distilled from the May 2026 `/team:team` verdict. Treat each as a gate.

**Ship-blockers (must land before App Store submission):**
- Move `DeleteBatchRecovery` breadcrumb update inside the delete for-loop at `SkymarshalCore/Services/ContentService.swift:289-318` so per-success state survives mid-batch crashes. ~5 LOC + a recovery test.
- Pre-flight estimated wall-clock time before any bulk delete ≥ 1,000 items. With a ~5k writes/hr PDS cap, a 50k nuke is 10+ hours and the UI currently does not say so up front.
- 15-min [USPTO TESS](https://tmsearch.uspto.gov) check on "Skymarshal" in the software-utility class.
- Rename **user-facing** "Bluescreen" to "Patterns" or "Signals" in listing copy + in-app labels. Internal codename keeps "Bluescreen" per the existing dignity-rename convention (`BluescreenAnalyzer` etc. stay).
- Reviewer-notes file for App Store submission citing `com.atproto.repo.deleteRecord` as a documented public AT Protocol lexicon, with link to the spec. Mitigates 5.2.2 / 4.3 review risk seen historically with Twitter cleanup apps.

**Parity gaps (small, close before App Store):**
- Content tab CSV/JSON export — follow the `Exporter.swift` Bluescreen pattern: hand-rolled FileHandle CSV (RFC 4180 + UTF-8 BOM) + per-element `JSONEncoder` framing + temp-file `UIActivityViewController`. **Do not use `Transferable` / `ShareLink`** — commit `5e3e66a` memorializes the crash.
- Alt-text search filter — one optional `altTextContains: String?` field on `SearchRequest` + one predicate clause.
- Timeframe quick-filter chips (7d / 30d / 90d / 1y) — pure UI sugar over the existing `dateFrom` / `dateTo`.

**v1.1 candidates (after launch):**
- "Danger Zone" bulk-by-category delete (all likes / all reposts / all follows) — high blast radius, pair with `TypedConfirmSheet` + countdown + the 429 ladder.
- Per-item delete parade (Python's `DeleteMode.INDIVIDUAL`).
- `Retry-After` / `ratelimit-reset` header parse in `ATProtoClient.performRaw:453-466`, threaded into `RateLimit.withBackoff` as an optional override (fixed ladder remains the fallback).

**Kill criteria (preserved from cynic, do not bury):**
- **Ship-blocker.** First 2 App Store submissions / threshold: rejection citing 5.0 or 4.3 on content-deletion grounds / action: do not appeal a third time — pivot to PWA at skymarshal.blue, keep iOS as a read-only audit companion.
- **Pivot-trigger.** Any 2026 Bluesky official-app release / threshold: ships native bulk-delete-by-filter / action: drop deletion as headline within 30 days; reposition entirely around Patterns (follower hygiene) + alt-text audit.
- **Sunset-trigger.** 6 months post-launch / threshold: MAU < 75 AND paid conversion < 1.0% AND App Store rating < 4.2 / action: archive iOS target, maintain Python CLI only.

## Marketing copy rules (apply to App Store listing too)

- Never use "AI", "AI-powered", "AI-enhanced", "AI-driven". If LLM features ever land, say "the on-device language model" or name the model.
- Don't reference internal tooling (skill names, agent names, "humanize", `/team`, etc.) in any user-facing prose, README, changelog, or release note.
- Author is Luke Steuber. Do not add `Co-Authored-By` to git commits.
