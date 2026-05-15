# Roadmap after decision (perf + chosen aesthetic)

**Date:** 2026-05-15  
**Depends on:** [PHASE4_DECISION_PACKAGE_2026-05-15.md](PHASE4_DECISION_PACKAGE_2026-05-15.md) — you must pick **A / B / C** (or request new moodboards).

---

## Track 1 — Performance (direction-agnostic, **do first**)

| Step | Work | Estimate |
|------|------|----------|
| 1.1 | **Instruments proof** on device: confirm `hydrate_from_cache` vs `root_cold_start_task` vs `session_restore` wall times. | 0.5 day |
| 1.2 | **Predicate fetch** for latest `ownerHandle` (or bounded page) + `@Index` on `ownerHandle` where schema allows. | 1–2 days |
| 1.3 | **Memoize / debounce** `ContentListView.filteredItems` + `BluescreenView.filtered`; throttle `loadProgress` UI updates if needed. | 1–2 days |
| 1.4 | Optional: **split** `@Observable` models to cut invalidation fan-out. | 2–4 days |

**Exit criterion:** Cold launch + first tab switch **feel** instant on your largest local cache (subjective) **and** main-thread spikes in Instruments drop below a agreed threshold (e.g. &lt;100 ms contiguous blocking).

---

## Track 2A — If **Brutalist** wins

| Step | Work | Estimate |
|------|------|----------|
| 2A.1 | `Theme.Brutalist` dynamic colors (phosphor / void) with WCAG check vs black **and** AX high-contrast alt. | 2 days |
| 2A.2 | Login + empty states + `SaturnButton` / chip restyle. | 2 days |
| 2A.3 | List chrome (row backgrounds, swipe affordances) without row-level glass. | 2–3 days |
| 2A.4 | Snapshot / AX5 UI test pass. | 1 day |

---

## Track 2B — If **Paper zine** wins

| Step | Work | Estimate |
|------|------|----------|
| 2B.1 | Bundle **Fraunces** + OFL attribution (mirror Plex pattern). | 0.5 day |
| 2B.2 | `Theme.Paper` tokens + **surface budget** (login + nav + chips only — per doubt doc). | 2 days |
| 2B.3 | Texture pipeline (optional) gated off on low power / Reduce Motion. | 1–2 days |
| 2B.4 | Dark “newsprint” palette + AX5 sweep. | 1–2 days |

---

## Track 2C — If **Cinematic** wins

| Step | Work | Estimate |
|------|------|----------|
| 2C.1 | Gradient + accent tokens; align `AccentColor` asset. | 1 day |
| 2C.2 | Login + panelized headers (`ultraThinMaterial` **only** on hero surfaces). | 1–2 days |
| 2C.3 | Copy + mono metrics strip audit so brand doesn’t read “generic SaaS.” | 1 day |

---

## Dependencies

- **Track 1** should merge before heavy Track 2 visual work so you don’t GPU-overdraw a still-O(n) list.
- All tracks: extend [`TokenCoverageTests`](../ios/SkymarshalTests/TokenCoverageTests.swift) if new color literals appear outside `Theme*`.
