# Scope navigation experiment (Q2 split)

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

## Hypothesis

Some users never enable the **Scope** tab (Feature lab default off) or bounce on an empty Scope surface. Others want Scope as a stable third tab. Consensus: collect **signal**, then choose **tab vs sheet-from-Insights**.

## On-device counters (no network)

`ScopeExperimentTelemetry` (`ios/SkymarshalCore/Standards/ScopeExperimentTelemetry.swift`) increments `UserDefaults` keys:

| Key (concept) | When incremented |
|---------------|------------------|
| `scopeHubAppearances` | `VisualizationHubView` appears (tab path). |
| `scopeOpenedFromInsights` | User opens the hub from the **Insights → Scope visualizations** link. |
| `scopeInsightsOfferImpressions` | The Insights section that advertises the link is shown. |

Read values in a beta with Terminal:

```bash
defaults read blue.skymarshal.ios
```

(or inspect the app’s preferences container in Settings → Developer if applicable).

`ScopeExperimentTelemetry.summary()` is available for debug menus or unit tests.

## Decision rubric (manual for v1)

1. If **Insights path opens** ≫ tab opens while the tab flag stays off → prioritize sheet / entry from Insights in release notes.  
2. If **tab opens** dominate once enabled → keep the tab; tighten empty states only.  
3. Re-run this doc after changing tab defaults or iOS tab chrome.

## Code switches

- Tab visibility: `FeatureFlags.visualizationHubKey` (About → Feature lab).  
- Insights link: `AnalyticsInsightsView` shows the NavigationLink when the tab flag is **off** so testers can reach Scope without permanent Content chrome.
