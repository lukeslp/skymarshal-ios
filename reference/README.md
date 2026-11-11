# Reference tree (frozen snapshot)

> **Retired.** This is reference material copied from earlier Skymarshal tools for the native iOS app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

This directory is **not** the shipping product. It preserves Python and TypeScript source lifted from upstream repos for **behavioral parity** when implementing and auditing the native iOS app.

## Shipping code

The production app lives under [`../ios/`](../ios/). Start with the repository root [`README.md`](../README.md) and [`AGENTS.md`](../AGENTS.md).

## What’s here

| Path | Role |
|------|------|
| [`python/`](python/) | Python reference: `ContentService` orchestration, deletion backoff, models, search — canonical behavior where TS disagrees (see [`../MIGRATION.md`](../MIGRATION.md)). |
| [`web/`](web/) | TypeScript/browser managers and pages — useful for structural mapping (facades, types); do **not** treat as authoritative over Python for backoff or engagement weights. |
| [`docs/`](docs/) | Archived **upstream** docs (CLI/API). For the **shipping iOS** documentation hub, use repo-root [`../docs/README.md`](../docs/README.md) — not this subtree’s `docs/README.md`. |
| [`sister-templates/`](sister-templates/) | XcodeGen / project patterns copied from related apps. |

## Lift date and provenance

Commits and the keep/drop rationale are recorded in [`../MIGRATION.md`](../MIGRATION.md) (lift **2026-05-09**).

**This tree is for parity checks and porting context,** not a second product to build or deploy from this repository.
