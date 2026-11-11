# Contributor UX — SwiftUI surfaces

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

This repo treats **documentation as part of the product boundary**: new screens should feel like Skymarshal, not like a generic template. The goal is **intentional** layout, typography, color, and motion — the same discipline as strong web product design, applied to SwiftUI and Apple HIG.

These rules align with workspace guidance and [`ios/SkymarshalCore/Standards/Theme.swift`](../ios/SkymarshalCore/Standards/Theme.swift). Visualization-specific tokens and graph rules: [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md).

---

## UX charter (operations console)

Skymarshal is **air-traffic control**, not a timeline client. Every screen should read as a **small control room**: one obvious primary task per region, dense data only where the user asked for it.

- **Hierarchy:** Prefer **progressive disclosure** — default Content uses a calmer chrome ([`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) **Full Content tools** toggle in the options menu and **About → Feature lab**). Type tabs, search, list, and destructive gates stay visible; optional stats strip tucks behind the toggle until the user opts in.
- **Differentiation:** Reuse established motifs (**DotBird** / dot-matrix header, **scope** iconography, leading stripe rows) instead of generic template chrome. Character comes from **rhythm** (spacing, weight, monospaced metadata), not from one-off decorations.
- **Typography:** Stay **Dynamic Type** safe. Prefer SF weights, tracking, and `monospacedDigit()` over custom fonts unless bundled with full AX testing. Never ship “AI” framing for on-device stats (see **Insights and analytics UI** below).
- **Liquid Glass:** Navigation layer only — never `.glassEffect()` on list rows or metric pills ([`docs/CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md) below).

---

## Color and status

- Use **`Theme`** tokens only for semantic states (`danger`, `caution`, `warn`, `scope`, `success`, `info`, `like`). Do not use raw `.red` / `.orange` / ad hoc RGB for user-visible status — light/dark contrast must stay legible.
- SF Symbols on **tinted chip backgrounds** use **`.symbolRenderingMode(.monochrome)`** so iOS does not substitute emoji-like fallbacks.

## Motion

- Route every animation through **`ReduceMotion.shouldReduce(systemReduceMotion:)`** (and respect `@AppStorage("sm.reduceMotionOverride")` where the app already does).
- Prefer one clear transition over scattered micro-motion.

## Navigation and density

- **Menu triggers** stay **icon + short word** only; put full dynamic state in the menu’s checkmarked rows or `.accessibilityLabel`, not in the trigger label (iOS 26 circular menus clip verbose text).
- **Row min-height:** Apple HIG floor **≥ 44 pt**; **ContentRow** and **AccountRow** ship **56 pt** minimum body height for dense metrics + text at default Dynamic Type. After changing row chrome, re-run **`SkymarshalUITests`** AX5 login test and spot-check Content in Simulator at **AX5** before App Store captures.
- Horizontal `ScrollView` chip rows: **`.contentMargins(.trailing, 24, for: .scrollContent)`** on the trailing end so the last chip is not clipped mid-glyph. Do not combine with `.scrollClipDisabled()` on the same axis unless you have a deliberate reason.

## Liquid Glass (iOS 26)

- System **TabView** pill / glass is intentional — do **not** paste `.glassEffect()` onto list rows or count pills. Glass belongs on the **navigation layer**, not data rows.

## Destructive and preview semantics

- **Bulk delete** thresholds and **`TypedConfirmSheet`** patterns are load-bearing — do not bypass for “convenience.”
- **Dry-run unfollow:** When the Followers tab toggle is on, **both** the bulk confirmation dialog and the **account detail** sheet call `AppModel.unfollow(dids:dryRun:)` / `FollowerService.unfollow(dids:dryRun:)` with `dryRun: true` — no `deleteRecord` XRPC, no removal from the in-memory scan list. Turn the toggle off for real unfollows.

## Insights and analytics UI

- **Insights** is on-device only — copy must never imply server-side analytics, third-party SDKs, or “AI” framing.
- Charts and histograms should remain readable at **Dynamic Type** sizes you support elsewhere.

## Where to look in code

| Concern | Primary files |
|---------|----------------|
| Content search / presets / sort / power strip | [`ContentListView.swift`](../ios/Skymarshal/UI/ContentListView.swift), [`AppModel.swift`](../ios/Skymarshal/UI/AppModel.swift) |
| Follower cleanup / dry-run | [`BluescreenView.swift`](../ios/Skymarshal/UI/BluescreenView.swift), [`FollowerService`](../ios/SkymarshalCore/Services/FollowerService.swift) |
| Profile lists | [`ProfileExplorerView.swift`](../ios/Skymarshal/UI/ProfileExplorerView.swift), [`ProfileService.swift`](../ios/SkymarshalCore/Services/ProfileService.swift) |
| Feature rollout + Feature lab | [`FeatureFlags.swift`](../ios/SkymarshalCore/Standards/FeatureFlags.swift), [`AboutView.swift`](../ios/Skymarshal/UI/AboutView.swift) |

## UI testing (XCUITest)

`SkymarshalUITests` uses **launch arguments** and **launch environment** keys that the app reads at startup (never in production user flows unless a test harness sets them):

| Key | Where read | Purpose |
|-----|------------|---------|
| `-uitestForceFeatureDiscovery` | [`RootView`](../ios/Skymarshal/UI/RootView.swift) | Opens the post-update About sheet without changing marketing version. |
| `-uitestStubMinimalContent` | [`AppModel`](../ios/Skymarshal/UI/AppModel.swift) | Injects one placeholder `ContentItem` so TabView mounts without sign-in. |
| `-uitestOpenInsights` | [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) | Presents Insights after a short async delay. |
| `UITEST_RESET_FEATURE_DEFAULTS` | [`SkymarshalApp`](../ios/Skymarshal/App/SkymarshalApp.swift) | Sets Insights feature on and Scope tab off in `UserDefaults` (test process isolation). |
| `UITEST_FORCE_BG_SCOPE_NOTE` | [`ContentListView`](../ios/Skymarshal/UI/ContentListView.swift) | Shows the background graph refresh honesty banner. |

Shared string constants: [`UITestBootstrap.swift`](../ios/SkymarshalUITests/UITestBootstrap.swift) (`XCUIApplication` extension).
