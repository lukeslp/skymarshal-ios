# Contributor UX — SwiftUI surfaces

This repo treats **documentation as part of the product boundary**: new screens should feel like Skymarshal, not like a generic template. The goal is **intentional** layout, typography, color, and motion — the same discipline as strong web product design, applied to SwiftUI and Apple HIG.

These rules align with workspace guidance and [`ios/SkymarshalCore/Standards/Theme.swift`](../ios/SkymarshalCore/Standards/Theme.swift).

---

## Color and status

- Use **`Theme`** tokens only for semantic states (`danger`, `caution`, `warn`, `scope`, `success`, `info`, `like`). Do not use raw `.red` / `.orange` / ad hoc RGB for user-visible status — light/dark contrast must stay legible.
- SF Symbols on **tinted chip backgrounds** use **`.symbolRenderingMode(.monochrome)`** so iOS does not substitute emoji-like fallbacks.

## Motion

- Route every animation through **`ReduceMotion.shouldReduce(systemReduceMotion:)`** (and respect `@AppStorage("sm.reduceMotionOverride")` where the app already does).
- Prefer one clear transition over scattered micro-motion.

## Navigation and density

- **Menu triggers** stay **icon + short word** only; put full dynamic state in the menu’s checkmarked rows or `.accessibilityLabel`, not in the trigger label (iOS 26 circular menus clip verbose text).
- **Row min-height** targets **≥ 44 pt**; dense follower rows may justify **56–60 pt** when bio + badges stack.
- Horizontal `ScrollView` chip rows: **`.contentMargins(.trailing, 24, for: .scrollContent)`** on the trailing end so the last chip is not clipped mid-glyph. Do not combine with `.scrollClipDisabled()` on the same axis unless you have a deliberate reason.

## Liquid Glass (iOS 26)

- System **TabView** pill / glass is intentional — do **not** paste `.glassEffect()` onto list rows or count pills. Glass belongs on the **navigation layer**, not data rows.

## Destructive and preview semantics

- **Bulk delete** thresholds and **`TypedConfirmSheet`** patterns are load-bearing — do not bypass for “convenience.”
- **Dry-run unfollow** (when enabled) applies to the **bulk confirmation** path in [`BluescreenView`](../ios/Skymarshal/UI/BluescreenView.swift). The **per-account** sheet from the same screen still calls `model.unfollow` on confirm — treat that as a **known product gap** until unified: either thread `dryRun` through `AppModel.unfollow` / `FollowerService` for all entry points, or make the detail confirmation copy explicit that dry-run does not apply there.

## Insights and analytics UI

- **Insights** is on-device only — copy must never imply server-side analytics, third-party SDKs, or “AI” framing.
- Charts and histograms should remain readable at **Dynamic Type** sizes you support elsewhere.

## Where to look in code

| Concern | Primary files |
|---------|----------------|
| Content search / presets / sort | [`ContentListView.swift`](../ios/Skymarshal/UI/ContentListView.swift), [`AppModel.swift`](../ios/Skymarshal/UI/AppModel.swift) |
| Follower cleanup / dry-run | [`BluescreenView.swift`](../ios/Skymarshal/UI/BluescreenView.swift), [`FollowerService`](../ios/SkymarshalCore/Services/FollowerService.swift) |
| Profile lists | [`ProfileExplorerView.swift`](../ios/Skymarshal/UI/ProfileExplorerView.swift), [`ProfileService.swift`](../ios/SkymarshalCore/Services/ProfileService.swift) |
| Feature rollout | [`FeatureFlags.swift`](../ios/SkymarshalCore/Standards/FeatureFlags.swift) |
