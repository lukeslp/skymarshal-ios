# Phase 4 — Decision package (perf + aesthetic)

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**Date:** 2026-05-15

You asked for cold-launch efficiency work **and** a full aesthetic rethink with `/team`-style rigor. This package is the **decision surface** — pick once, then execute in a follow-up branch.

---

## A. Cold launch — what we know

| Artifact | Action |
|----------|--------|
| [PERF_COLDLAUNCH_2026-05-15.md](PERF_COLDLAUNCH_2026-05-15.md) | Read signpost map + ranked hotspots + observation appendix. |
| [ARCH_VERDICT_2026-05-15.md](ARCH_VERDICT_2026-05-15.md) | Internal technical committee verdict. |
| [CONSENSUS_ARCH_PERF_2026-05-15.md](CONSENSUS_ARCH_PERF_2026-05-15.md) | External second opinions (Mistral only this run). |

**Decision:** Treat **predicate-scoped SwiftData fetch + memoized `filteredItems`** as the first engineering bet; **split `AppModel`** only after those are measured on a large device trace.

---

## B. Aesthetic — three directions (pick one)

| ID | Doc | One-line vibe |
|----|-----|---------------|
| **A** | [AESTHETIC_BRUTALIST_2026-05-15.md](AESTHETIC_BRUTALIST_2026-05-15.md) | CRT / radar console — mono hero, maximum differentiation, legibility risk. |
| **B** | [AESTHETIC_PAPER_2026-05-15.md](AESTHETIC_PAPER_2026-05-15.md) | Riso / broadsheet — Fraunces + paper + mono metrics; warmth + archive. |
| **C** | [AESTHETIC_CINEMATIC_2026-05-15.md](AESTHETIC_CINEMATIC_2026-05-15.md) | OLED gradient “pro” shell — fastest path from current UI; generic SaaS risk. |

**Doubt (if leaning B):** read [AESTHETIC_DOUBT_PAPER_2026-05-15.md](AESTHETIC_DOUBT_PAPER_2026-05-15.md) before committing.

---

## C. Your checklist (copy into an issue)

- [ ] Record one **Instruments** trace on a **physical device** with your real account size (Points of Interest: `blue.skymarshal.ios` / `ColdLaunch`).
- [ ] Choose **A**, **B**, or **C** (or “none — iterate new moodboards”).
- [ ] Confirm perf gate order: **fetch → memoize → (optional) split model**.
- [ ] If **B** or **A**: schedule **AX5 + increased contrast** pass before TestFlight.

---

## D. What was shipped in code this round

- `ColdLaunchSignposts` + wiring in `SkymarshalApp`, `AppModel`, `RootView`, tab roots.
- `ColdLaunchHydrationPatternTests` (XCTMeasure mirror of hydrate fetch pattern).
- **`FeatureFlags.applyLaunchArgumentOverrides(from:)`** — parses `-sm.feature.* YES|NO` pairs into `UserDefaults` so XCUITest flags reach `@AppStorage` (fixes Scope tab / Style capture tests).
- **UI test hygiene:** `UITEST_RESET_FEATURE_DEFAULTS` on login-only launches + **stub seed** now includes one `AnalyzedAccount` for Scope completeness assertions.
- Unit tests: `FeatureFlagsLaunchArgumentTests`.

No **aesthetic** restyle in this tranche — only cold-launch instrumentation + test/flag correctness.
