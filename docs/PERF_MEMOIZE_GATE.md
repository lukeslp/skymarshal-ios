# Memoize / debounce gate (conditional Track 1)

**Status:** Deferred until post-soak Instruments evidence.

## Rule

Ship `CacheHydration` predicate fetches first. Only add memoization or debouncing on:

- `ContentListView.filteredItems`
- `BluescreenView.filtered`

if a **physical-device** soak trace (see [SOAK_PROTOCOL.md](SOAK_PROTOCOL.md)) still shows **&gt;100 ms contiguous main-thread** work during filter passes after predicate hydration lands.

## Do not ship in this tranche

- `@Observable` `AppModel` split (YAGNI at current property count)
- Engagement-cache SQLite wiring (`F-engagement-cache`)

## Evidence to attach when implementing memoize

- Instruments signpost or Time Profiler slice name
- Account size (item count)
- Before/after ms on main thread
