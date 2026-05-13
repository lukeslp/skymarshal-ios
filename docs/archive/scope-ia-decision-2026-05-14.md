# Scope navigation decision (tab vs Insights entry)

**Date:** 2026-05-14  
**Inputs:** [`docs/SCOPE_IA_EXPERIMENT.md`](../SCOPE_IA_EXPERIMENT.md), on-device counters in [`ScopeExperimentTelemetry`](../../ios/SkymarshalCore/Standards/ScopeExperimentTelemetry.swift).

## Telemetry snapshot (fill from `defaults read` or in-app debug)

| Metric | Value (TBD) |
|--------|-------------|
| `scopeHubAppearances` | |
| `scopeOpenedFromInsights` | |
| `scopeInsightsOfferImpressions` | |

Call `ScopeExperimentTelemetry.summary()` from a DEBUG-only panel or unit test host when convenient.

## Rubric (from roadmap E1/E2)

1. If **Insights path opens** are a large share of Scope engagement while the **tab flag stays off**, bias toward **Insights-first** entry in release notes and consider fewer tab surfaces.
2. If **tab appearances** dominate once users enable Scope, **keep the tab** and improve empty/loading copy only.

## Decision

**Outcome:** Pending — populate the table after **two** TestFlight builds or a deliberate internal cohort, then set **Outcome** to `KeepTab` or `InsightsPrimary` with one sentence rationale.

## Follow-up engineering (only after decision)

- UITest that toggles Feature lab via launch args and asserts Scope tab visibility **or** Insights link-only path.
- Copy tweaks in [`AboutView`](../../ios/Skymarshal/UI/AboutView.swift) / [`AnalyticsInsightsView`](../../ios/Skymarshal/UI/AnalyticsInsightsView.swift) per outcome.
