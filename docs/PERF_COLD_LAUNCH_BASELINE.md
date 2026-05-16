# Cold-launch hydration baseline

**Purpose:** Record a simulator baseline *before* predicate-scoped SwiftData fetches land, then compare after `CacheHydration` ships.

## Automated wall-clock probe

From `ios/`:

```bash
xcodebuild test -scheme Skymarshal \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SkymarshalTests/ColdLaunchHydrationPatternTests/test_measure_hydrationFetchPattern_wallClock
```

`ColdLaunchHydrationPatternTests` now exercises the **predicate path** (`CacheHydration.latestOwnerHandle` + `contentRecords(for:)`).

## Instruments (device — required before public release)

1. Physical iPhone, signed-in account with your largest local cache (≥10k posts ideal).
2. Xcode → Product → Profile → **Time Profiler** + **os_signpost**.
3. Filter subsystem: `blue.skymarshal.ios`.
4. Cold launch: force-quit → relaunch → wait until Content tab shows rows.
5. Capture intervals: `hydrate_from_cache`, `root_cold_start_task`, `tab_content_appear`.
6. Save trace to `docs/soak/baseline-YYYY-MM-DD.trace` (git-lfs or attach to soak artifact folder).

## Exit criterion (Track 1)

Subjective: cold launch + first tab switch feel instant on largest cache.  
Objective: contiguous main-thread blocking **&lt; 100 ms** during `hydrate_from_cache` on device trace.

## Memoize gate

Do **not** add `filteredItems` / `filtered` memoization unless post-soak Instruments still shows &gt;100 ms spikes. See [PERF_MEMOIZE_GATE.md](PERF_MEMOIZE_GATE.md).
