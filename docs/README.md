# Documentation hub

Skymarshal documentation is split by **job**: ship the app, understand architecture, or run a structured review. Pick a lane and go deep in one file instead of skimming everything.

---

## Start here

| If you are… | Read |
|-------------|------|
| **New to the repo** | Root [`README.md`](../README.md) → [`AGENTS.md`](../AGENTS.md) |
| **Implementing a feature** | [`ARCHITECTURE.md`](ARCHITECTURE.md) → [`CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md) → optional flags in [`FeatureFlags`](../ios/SkymarshalCore/Standards/FeatureFlags.swift) |
| **Comparing to upstream Python/web** | [`UPSTREAM_FEATURE_GAP.md`](UPSTREAM_FEATURE_GAP.md) + [`MIGRATION.md`](../MIGRATION.md) |
| **Preparing App Store / privacy** | [`../app-store/`](../app-store/) + [`../ios/Skymarshal/PrivacyInfo.xcprivacy`](../ios/Skymarshal/PrivacyInfo.xcprivacy) |

---

## Architecture and product scope

| Document | Purpose |
|----------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | iOS layers, orchestration boundary, services, network, SwiftData, standards. |
| [UPSTREAM_FEATURE_GAP.md](UPSTREAM_FEATURE_GAP.md) | Scope map: what shipped in iOS vs upstream stacks (not an implicit backlog). |
| [PARITY_VISUALIZATION_PLAN.md](PARITY_VISUALIZATION_PLAN.md) | Phased parity + visualization roadmap with risk gates and 90-day execution timeline. **Phases 1–2** (advanced search, preflight, graph schema, hub alpha, word patterns, backup import, graph writer) are on `main` behind default-off feature flags — see [`ARCHITECTURE.md`](ARCHITECTURE.md) “Imported upstream-adjacent surfaces”. |
| [UX_SPEC.md](UX_SPEC.md) | IA and wireframe-level UX spec for advanced search, delete review, backups, and visualization hub. |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Ops-console visual language, graph encoding/accessibility standards, and implementation checklist. |

---

## Review and council artifacts (roadmap branch)

Used for merge discipline on large tranches (insights, power-search, cleanup, explorer).

| Artifact | Purpose |
|----------|---------|
| [REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md](REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md) | Single canonical prompt / facts for `/team` and `/consensus`. |
| [TEAM_CONSENSUS_DECISION_PACKAGE.md](TEAM_CONSENSUS_DECISION_PACKAGE.md) | Matrix, committee synthesis, Option A vs B, execution gates. |
| [archive/council-raw/](archive/council-raw/) | Raw CLI attempt logs (Gemini / Codex / Cursor-agent) — advisory only; see folder `README`. |
| [archive/consensus-skymarshal-ios-2026-05-13.md](archive/consensus-skymarshal-ios-2026-05-13.md) | 2026-05-13 `/consensus` matrix (**Codex** + **Claude Code** transcripts; Gemini 499 noted) + merged read + re-run instructions; prompt in [`consensus-skymarshal-ios-PROMPT.txt`](archive/consensus-skymarshal-ios-PROMPT.txt). |

---

## Contributor UX (SwiftUI)

| Document | Purpose |
|----------|---------|
| [CONTRIBUTOR_UX.md](CONTRIBUTOR_UX.md) | Intentional UI patterns: Theme, motion, menus, destructive flows — avoid generic “stock SwiftUI” drift. |

---

## Frozen reference (not shipping)

| Path | Purpose |
|------|---------|
| [`../reference/README.md`](../reference/README.md) | Why `reference/` exists and how to use it for parity. |
| [`../reference/docs/README.md`](../reference/docs/README.md) | Archived upstream CLI docs (historical). |
