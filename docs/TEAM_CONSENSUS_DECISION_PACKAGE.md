# Team + consensus decision package

**Branch:** `cursor/ios-roadmap-imports` → `main`  
**PR:** https://github.com/lukeslp/skymarshal-ios/pull/2  
**Canonical brief:** [REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md](REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md) (identical prompt seed: `/tmp/consensus-ios-roadmap.txt`)

This document implements the **Full /team + /consensus execution plan**: frozen brief, consensus transports, full council synthesis, merged recommendation, and actionable merge/split tracks.

---

## Consensus matrix

**Voices attempted**

| Transport | Model / tool | Result |
|-----------|----------------|--------|
| Codex CLI | `codex exec` (read-only, ephemeral) | **Skipped** — run exceeded time budget; no model verdict captured (see `docs/CONSENSUS_CODEX.txt` placeholder). |
| Gemini CLI | `gemini-2.5-flash` | **Completed** — see `docs/CONSENSUS_GEMINI.txt`. |
| Cursor CLI | `cursor-agent` | **Skipped** — authentication required (`agent login` / `CURSOR_API_KEY`). |
| API fallback | `~/documentation/API_KEYS.md` | **Skipped** — file not present in this environment. |
| Local gateway | `localhost:5200` | **Skipped** — not used per skill (no attempt). |

| # | Question | Gemini 2.5 Flash | Codex | Cursor-agent | Verdict |
|---|----------|------------------|-------|--------------|---------|
| 1 | Merge as **one PR** vs **split**? | **AGREE** (one PR) — efficient review/integration for related work | (no output) | (skipped) | **Split signal: weak** — single external voice; treat as input only. |
| 2 | Top concrete risk | Pagination / data display issues in profile explorer | — | — | **Profile graph + rate limits + truncation** (aligns with internal recon). |
| 3 | Highest-value pre-merge check | Integration tests for pagination / `ProfileExplorerView` | — | — | **Full `xcodebuild test` + scripted dry-run matrix** (internal team tightens this below). |
| 4 | Kill criterion | Unfixable build / fundamental xcodegen workflow break | — | — | **CI green + no “preview” path performing real unfollow** (see Notable). |
| 5 | Confidence | Medium | — | — | **Low–medium** for consensus row alone. |

### Notable objections (internal recon, not from Gemini)

- **Dry-run bypass:** `BluescreenView` bulk confirmation respects `unfollowDryRun`; the `AccountDetailView` sheet path calls `model.unfollow(dids:)` directly (~line 352) without the same gate — user can believe “preview only” and still issue a real unfollow from the detail sheet.
- **Test gap vs surface area:** New automated coverage is concentrated in `AnalyticsServiceTests`; presets, `ProfileService`, `CleanupPreset` branches, and dry-run policy deserve targeted tests before treating CI as sufficient.

---

## Full /team council output (condensed)

Full structured committee markdown was generated in-session from the canonical brief (research, business, technical, skeptics, executive). Summary below preserves **dissent**.

### Research (facts)

- ~29 files, +1259/−144; commits `7aad395`, `98f8f29`.
- New surfaces: on-device analytics, saved searches + sort, cleanup presets, unfollow dry-run (partial), profile explorer, `FeatureFlags`, SwiftData preset record, docs + reference cleanup.
- `project.yml` uses directory sources — regen must stay consistent with committed `project.pbxproj`.

### Business committee

- **AGREE (one PR)** for narrative cohesion (single TestFlight story).
- Risks: positioning drift if explorer/cleanup feels like “network analytics” vs on-device air-traffic framing.

### Technical committee

- **AGREE (one PR)** for cohesion of `AppModel` / `ContentListView` / follower flows.
- Risks: `ProfileService` pagination volume (latency, 429s, `maxPages` truncation), `Calendar.current` semantics for insights, thin tests on new paths.

### Skeptics committee (dissent preserved)

- **DISAGREE / WAIT on one PR:** mixes low-risk analytics, network-heavy graph reads, destructive-adjacent follower actions, and doc/reference churn — **bisectability** and rollback granularity suffer.
- Recommends **split** (e.g. analytics+docs vs explorer+cleanup+presets) **or** fix dry-run policy before single merge.

### Executive verdict (synthesized)

- **Decision line:** Ship the capability set after **resolving dry-run vs detail-sheet unfollow** (fix or explicitly document as intentional) and running **full integration tests**; **one PR is acceptable if schedule dominates**, with **documented dissent** on bundle size.
- **Confidence:** ~**0.68** (executive run) — raised by pure analytics + tests; lowered by graph stress, dry-run inconsistency, thin coverage on new network/UI paths.

---

## Merged recommendation (consensus + team)

| Path | When to choose |
|------|----------------|
| **Option A — Merge one PR** | You accept bisect debt; you **fix or document** the detail-sheet unfollow vs dry-run behavior; **full** `xcodegen generate` + `xcodebuild test` green; manual scripted matrix passes. |
| **Option B — Split now** | You prioritize **rollback isolation** and reviewer focus; split roughly: (1) analytics + insights + tests + low-risk docs, (2) saved search / sort / storage + tests, (3) cleanup presets + dry-run policy + follower UI, (4) profile explorer + `ProfileService` + networking + remaining docs/reference. |

**Default recommendation:** **Option B** if any kill criterion below fails; **Option A** only with explicit dry-run policy resolution and green full test run.

---

## Execution gates (pre-merge)

1. **`xcodegen generate`** — diff against committed `ios/Skymarshal.xcodeproj/project.pbxproj`; resolve intentional drift.
2. **`xcodebuild test`** — full scheme including UI tests when simulator is stable; at minimum `SkymarshalTests` must be green.
3. **Dry-run matrix (manual)** — with `unfollowDryRun` on: bulk “simulate” shows banner and **no** XRPC unfollow; **detail-sheet unfollow** must either match that contract or show copy that dry-run does not apply there.
4. **Profile explorer** — large account: scroll, cancel, error path; confirm no unbounded memory growth on repeated pagination.
5. **Privacy / App Store alignment** — insights and explorer remain on-device + direct XRPC story; update nutrition labels if new data classes appear.

---

## First three moves after you accept this package

1. Choose **Option A or B** using the table above.
2. If **Option A:** implement dry-run policy fix (single choke point in `AppModel.unfollow` / `FollowerService`) **or** ship explicit UI copy on the detail path; re-run tests.
3. If **Option B:** create stacked branches from current `cursor/ios-roadmap-imports` tip in the split order above; close or supersede the monolithic draft PR as needed.

---

## Files produced by this plan run

| File | Purpose |
|------|---------|
| [REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md](REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md) | Canonical brief (Phase 1). |
| [CONSENSUS_GEMINI.txt](CONSENSUS_GEMINI.txt) | Raw Gemini CLI output. |
| [CONSENSUS_CODEX.txt](CONSENSUS_CODEX.txt) | Codex attempt log (timeout). |
| [CONSENSUS_CURSOR_AGENT.txt](CONSENSUS_CURSOR_AGENT.txt) | Cursor-agent attempt (auth failure if empty). |
| This file | Phases 4–6 synthesis. |

---

## Documentation cross-links (post-review refresh)

- **Hub:** [docs/README.md](README.md) — single entry table for all `docs/` artifacts.
- **SwiftUI / destructive semantics checklist** (intentional product UI, not generic templates): [CONTRIBUTOR_UX.md](CONTRIBUTOR_UX.md) — incorporates `/team` + `/consensus` findings (e.g. dry-run scope, pre-merge manual matrix).

When updating this package after new council runs, append dated rows to the consensus matrix rather than overwriting historical transport results.
