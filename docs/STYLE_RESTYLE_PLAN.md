# Style restyle plan — Move #2 + Move #3

**Predecessor:** [`STYLE_DIAGNOSIS_2026-05-14.md`](STYLE_DIAGNOSIS_2026-05-14.md) (Move #1)
**Owners:** `ios/Skymarshal/UI/*` + `ios/SkymarshalCore/Standards/*`
**Releases this plan spans:** v1.0.1 (rows 1, 2, 5) and v1.0.2 (rows 3, 4, 6, 7)
**Re-verification harness:** [`ios/SkymarshalUITests/StyleDiagnosisCapture.swift`](../ios/SkymarshalUITests/StyleDiagnosisCapture.swift)

This document is the executable implementation plan for the seven-row first-strike
table in the diagnosis. The diagnosis answers *what* and *why*; this plan answers
*which files, in what order, with what guard rails, and what kills the move*.

---

## 1) Scope and non-goals

### In scope — v1.0.1 (low-risk, type-and-button pass)

| Row | Move | Surface |
|----:|------|---------|
| 1 | Plex Mono on tabular numbers + kicker timestamps | `ContentRow`, `ContentListView` subhead, `ScanSummaryStrip` pills, `AccountRow` metric row, `LoadProgressBanner`, `BotScoreBadge` |
| 2 | Status pills → `ScopePill` (Theme-muted + Plex Mono caps) | `VisualizationHubView` `Unknown`/`Partial`, `BotScoreBadge` container |
| 5 | `.borderedProminent` → `SaturnButton` (sharp 3px radius, paper fill, ink border) | `LoginView` "Sign in", `BluescreenView` "Begin scan" |

### In scope — v1.0.2 (paper-ground + serif pass)

| Row | Move | Surface |
|----:|------|---------|
| 3 | Filter chip row → typographic kicker tags | `ContentListView` `TypeChipsRow` replacement |
| 4 | Saturn paper-bone background + ink hairlines | App-wide list rows + section separators |
| 6 | Fraunces variable serif on display titles | All `.large` nav titles + `BluescreenView` empty-state hero + `AnalyticsInsightsView` section headers |
| 7 | Hairline-square nav icons replacing iOS 26 circle-behind-icon | All toolbar items |

### Non-goals (locked-in — do NOT touch)

- **Liquid Glass `TabView` pill.** Intentional iOS 26 system rendering per `CLAUDE.md` ("lean in, don't override"). The pill IS the navigation chrome; restyling it breaks the platform contract.
- **System `.searchable` field.** Replacing it costs the `.searchable` text-binding behavior that drives `ContentListView`'s `keyword` state, `pruneSelectionToVisible()`, and the AX5 search-focus path. No reason to roll our own.
- **DotBird hero image + `Skymarshal` wordmark + "Air-traffic control for your Bluesky." tagline.** Brand identity per `CLAUDE.md`. Do not retype, retint, or reskin.
- **`Theme.danger / .caution / .warn / .scope / .success / .info / .like` semantic tokens.** Move #2/#3 *adds* paper/ink/hairline tokens; it does **not** remove or repaint the existing seven. Light/dark contrast tuning is load-bearing.
- **`RateLimit.withBackoff`, `ReduceMotion.shouldReduce`, `TypedConfirmSheet` thresholds, dry-run unfollow plumbing, Keychain session, "AI" copy ban, "app password" language, app-password external link.** Plan is presentation-only.
- **`Co-Authored-By` git trailer.** Per `CLAUDE.md` author rule — no Claude attribution in commit messages.

---

## 2) Font shipping path (one-time setup for v1.0.1)

### 2.1 Where the OTFs live

Create a new directory at:

```
ios/Skymarshal/Resources/Fonts/
```

(Confirmed not to exist today — `ls ios/Skymarshal/` returns `App  Assets.xcassets  Info.plist  PrivacyInfo.xcprivacy  Skymarshal.entitlements  UI` with no `Resources/`.)

### 2.2 Which Plex Mono weights for v1.0.1

Minimum three weights, enough for `kicker` + `body` + `tabular emphasis`:

- `IBMPlexMono-Regular.otf` (weight 400)
- `IBMPlexMono-Medium.otf`  (weight 500)
- `IBMPlexMono-SemiBold.otf` (weight 600)

Italics are **not** shipped in v1.0.1 — none of the surfaces in rows 1+2 use italic mono.
Fraunces (all weights) ships in v1.0.2; see §7.

### 2.3 `Info.plist` `UIAppFonts` entry (added via `project.yml`)

The app target's Info.plist is generated inline in `project.yml` (`targets.Skymarshal.info.properties`). Add this key alongside the existing `BGTaskSchedulerPermittedIdentifiers` block:

```yaml
        UIAppFonts:
          - IBMPlexMono-Regular.otf
          - IBMPlexMono-Medium.otf
          - IBMPlexMono-SemiBold.otf
```

For v1.0.2, append the Fraunces files in the same array.

### 2.4 `project.yml` resource path

XcodeGen auto-classifies `.otf` under `sources:` as Copy Bundle Resources, so no `resources:` block is strictly required. However, for explicitness and to keep the asset bundle visible in the spec, add an explicit excludes-or-include rule under the `Skymarshal` target. Recommended diff (concept, not literal):

```yaml
  Skymarshal:
    type: application
    platform: iOS
    sources:
      - path: Skymarshal
        excludes:
          - "Resources/Fonts/.gitkeep"   # only if a placeholder is added
```

Default recursion under `path: Skymarshal` already picks up `Resources/Fonts/*.otf`. The `excludes` line is only needed if you drop a `.gitkeep` placeholder. Regenerate the Xcode project after the change:

```bash
cd ios && xcodegen generate --spec project.yml
```

### 2.5 PostScript names used in `UIFont(name:size:)`

**Heads-up — naming has drifted across upstream releases.** IBM Plex 6.0.0 (Sep 2021) abbreviated certain weight names in the PostScript table:

| Weight | Pre-6.0 PostScript | 6.0+ PostScript |
|-------:|--------------------|-----------------|
| Regular | `IBMPlexMono` | `IBMPlexMono` (unchanged) |
| Medium | `IBMPlexMono-Medium` | `IBMPlexMono-Medm` |
| SemiBold | `IBMPlexMono-SemiBold` | `IBMPlexMono-SmBld` |

The diagnosis doc assumed `-Medium` / `-SemiBold`. **That assumption is unsafe on a fresh download from `github.com/IBM/plex` releases after 6.0.** The implementation MUST:

1. Drop the OTFs into `Resources/Fonts/`.
2. Run the simulator once and dump `UIFont.fontNames(forFamilyName: "IBM Plex Mono")` to the console.
3. Use the literal names that appear in that array as the strings passed to `Font.custom(...)`.
4. Encode both candidates in `Theme.Mono` with a fallback chain — see §3.

Do NOT guess. The `Theme.audit()` DEBUG assertion (§2.7) is the safety net that catches this on every launch in DEBUG.

### 2.6 Font licensing — ship the OFL attribution

Both Plex and Fraunces are SIL OFL 1.1. Apple does not require shipping OFL.txt inside the bundle, but the OFL itself requires *the copyright statement and the license shall be included in all copies of the Font Software, in source or binary form, except as embedded only in the Font Software*. Embedded-only is fine for app bundling, but per the workspace LICENSE rule (`LICENSE_FONTS.md` already exists as a convention parallel to `LICENSE`), ship the attribution under:

```
app-store/LICENSE_FONTS.md
```

Contents for v1.0.1 (one entry, IBM Plex Mono only):

```markdown
# Font licenses

Skymarshal bundles the following open-source typefaces under the SIL Open Font License 1.1.

## IBM Plex Mono

Copyright © 2017 IBM Corp. with Reserved Font Name "Plex".

Distributed under the SIL Open Font License 1.1 — https://scripts.sil.org/OFL.
Upstream: https://github.com/IBM/plex
```

For v1.0.2, append a `## Fraunces` block with the Undercase LLC attribution and the upstream `github.com/undercase/Fraunces` URL.

### 2.7 DEBUG-only `Theme.audit()` assertion

This is greybeard's "silent-fallback failure mode" insurance. In RELEASE, a missing
PostScript name silently falls back to the system font and ships broken to the
App Store — which is exactly the failure mode that "register your fonts" tutorials
never catch. In DEBUG, the app should refuse to launch if any font we registered
is missing from `UIFont.fontNames(forFamilyName:)`.

Add to `Theme+Fonts.swift` (the new file from §3):

```swift
#if DEBUG
public static func audit() {
    let expected: [String: [String]] = [
        "IBM Plex Mono": [
            "IBMPlexMono",
            // Accept either the pre-6.0 or 6.0+ spelling; one of each pair
            // must resolve at launch.
            "IBMPlexMono-Medium", "IBMPlexMono-Medm",
            "IBMPlexMono-SemiBold", "IBMPlexMono-SmBld",
        ],
    ]
    for (family, candidates) in expected {
        let resolved = Set(UIFont.fontNames(forFamilyName: family))
        let anyHit = candidates.contains { resolved.contains($0) }
        precondition(anyHit, "Theme.audit: \(family) not registered (got \(resolved)).")
    }
}
#endif
```

Wire from `AppDelegate` / `App.init` behind `#if DEBUG`. Production builds skip the
check (we don't want to crash a real user over a font registration miss — we want
the test suite + manual smoke to catch it).

---

## 3) New files to create

All file paths are repo-rooted. No file is more than ~150 lines; component scope is deliberately small.

### 3.1 `ios/SkymarshalCore/Standards/Theme+Fonts.swift` (v1.0.1)

**Responsibility:** Wrap `Font.custom(...)` with a fallback chain so missing fonts cleanly degrade. Adds `Theme.Mono` and (in v1.0.2) `Theme.Display`.

Public surface (v1.0.1):

```swift
extension Theme {
    public enum Mono {
        public static func kicker(_ size: CGFloat = 11) -> Font     // SemiBold, tracking-friendly
        public static func body(_ size: CGFloat = 13) -> Font       // Regular
        public static func tabular(_ size: CGFloat = 13) -> Font    // Medium, monospaced digits
        public static func caption(_ size: CGFloat = 11) -> Font    // Regular
    }
}
```

Each helper is `Font.custom("IBMPlexMono-…", size: x, relativeTo: .caption2)` so Dynamic Type still scales — `relativeTo:` is **non-optional** for AX5 compliance.

If the lookup fails at runtime, return `.system(.body, design: .monospaced)`. The `Theme.audit()` assertion crashes DEBUG before this fallback can hide a regression.

### 3.2 `ios/SkymarshalCore/Standards/Theme+Saturn.swift` (v1.0.2 — DO NOT SHIP IN v1.0.1)

**Responsibility:** Paper / ink / hairline tokens via the existing `UIColor(dynamicProvider:)` pattern.

Public surface:

```swift
extension Theme {
    public static let paper        = dynamic(light: 0xF4F1EA, dark: 0x17160F)
    public static let paperRaise   = dynamic(light: 0xEFEBE1, dark: 0x1E1D15)
    public static let ink          = dynamic(light: 0x161616, dark: 0xF3EFE4)
    public static let inkSoft      = dynamic(light: 0x3F3F3F, dark: 0xD4CFC2)
    public static let muted        = dynamic(light: 0x6B6863, dark: 0xA09C92)
    public static let hairline     = dynamic(light: 0x161616, dark: 0xF3EFE4).opacity(0.14)
    public static let hairlineStrong = dynamic(light: 0x161616, dark: 0xF3EFE4).opacity(0.32)
}
```

Note the deliberate swap: Saturn's `#CE3526` ("hot") interactive accent is **not** ported. Skymarshal already has `Theme.scope = #0066CC` as the brand interactive color, and the dreamer reference explicitly recommends keeping Bluesky-blue on interactive states for our case. Saturn's `hot` only enters Skymarshal as a *destructive* accent — and `Theme.danger` already covers that. So Saturn paper/ink/muted/hairline are added; Saturn hot is not.

**Operational status overlay (from the bioluminescent mission-control variant):** the diagnosis lists `ok=#22aa55`, `warn=#ccaa44`, `alert=#cc4444` as a sketch. Compare to current Theme tokens:

| Current | Overlay sketch | Decision |
|---------|----------------|----------|
| `Theme.success = #1E7A30` (light) / `#4EC56A` (dark) | `#22aa55` | Keep current — `#1E7A30` already clears WCAG 1.4.11 on `systemBackground`; `#22aa55` does not in light mode. |
| `Theme.caution = #B36100` (light) / `#FFB940` (dark) | `#ccaa44` | Keep current — same WCAG reason. |
| `Theme.danger = #C8312A` (light) / `#FF6B5C` (dark) | `#cc4444` | Keep current. |

The status palette overlay is a *reference for taste*, not a token replacement. The existing seven Theme tokens stay exactly as they are.

### 3.3 `ios/Skymarshal/UI/Components/SaturnButton.swift` (v1.0.1)

**Responsibility:** `ButtonStyle` rendering a sharp-3px-radius button with paper fill + 1px ink border. Replaces `.borderedProminent` on the two CTAs in `LoginView` + `BluescreenView` empty state.

**Surface contract:**

```swift
@available(iOS 17, *)
public struct SaturnButton: ButtonStyle {
    public enum Emphasis { case primary, ghost, destructive }
    public var emphasis: Emphasis = .primary
    public func makeBody(configuration: Configuration) -> some View
}
```

- `.primary`: paper fill, 1px ink stroke, ink text, scope-blue (`Theme.scope`) on `isPressed`. **No drop shadow** — Saturn discipline.
- `.ghost`: clear fill, 1px ink stroke, ink text. Used for secondary actions if we add one later in v1.0.2.
- `.destructive`: `Theme.chipTint(Theme.danger)` fill, `Theme.danger` border, `Theme.danger` text. Not used in v1.0.1 (the only destructive CTA today is "Sign out", which stays inside a `Menu`).

**Disabled state:** `Theme.muted` foreground, `Theme.hairline` border. Same 3px corner radius. Per HIG, disabled buttons stay hit-testable for focus but `.disabled(true)` still suppresses the action.

**Dynamic Type:** uses `Theme.Mono.body(15)` for v1.0.1 (Plex Mono Regular @ 15pt). In v1.0.2 once Fraunces ships, the CTA label can optionally route through `Theme.Display.subhead` — but **not** mandatory; mono on the button keeps the operational read.

**Note on `Theme.paper` dependency:** `SaturnButton` references the paper/hairline tokens which only ship in v1.0.2. In v1.0.1 the button uses `Color(.systemBackground)` for fill and `Color.primary.opacity(0.32)` for the stroke as a temporary shim. The shim is replaced in v1.0.2 when `Theme+Saturn.swift` lands. Document the shim in a single source-level comment so it's not forgotten.

### 3.4 `ios/Skymarshal/UI/Components/ScopePill.swift` (v1.0.1)

**Responsibility:** Replacement for `Picker.borderedProminent` status chips on the Scope tab + `BotScoreBadge` container.

```swift
@available(iOS 17, *)
public struct ScopePill: View {
    public let value: String
    public let label: String?
    public var emphasis: Emphasis = .muted   // .muted | .scope | .danger | .caution | .success
    public var body: some View
}
```

- Plex Mono SemiBold caps text via `Theme.Mono.kicker(11)`.
- Background: `Theme.chipTint(...)` keyed by emphasis (uses the existing alpha-0.18 helper — preserves the established WCAG floor).
- Sharp 3px radius.
- Padding: 8pt horizontal, 3pt vertical (Saturn density).
- `.symbolRenderingMode(.monochrome)` on any leading SF Symbol (per the existing standard).
- `accessibilityLabel` defaults to `"\(label ?? "") \(value)"`; caller can override.

`ScopePill` REPLACES the current ad hoc `Pill` private struct inside `ScanSummaryStrip.swift` and the inline `Pill` inside `AccountRow.swift > StatusPills`. Both ad hoc pills get removed in the same move.

### 3.5 `ios/SkymarshalTests/TokenCoverageTests.swift` (v1.0.1)

**Responsibility:** Token-coverage XCTest that fails the build if `grep` finds raw color literals outside `Theme*.swift`. Greybeard's tripwire.

```swift
final class TokenCoverageTests: XCTestCase {
    func test_noRawStatusColorsOutsideTheme() throws {
        let regex = #"(?<!\w)(\.red|\.orange|\.yellow|Color\.red|Color\.orange|Color\.yellow)(?!\w)"#
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // SkymarshalTests/
            .deletingLastPathComponent()    // ios/
        let scan = root.appendingPathComponent("Skymarshal")
        let core = root.appendingPathComponent("SkymarshalCore")
        try assertNoMatches(under: scan, regex: regex, allowingFilesNamed: [])
        try assertNoMatches(under: core, regex: regex, allowingFilesNamed: ["Theme.swift", "Theme+Fonts.swift", "Theme+Saturn.swift"])
    }
}
```

**Why a runtime test and not a build script:** XcodeGen specs are noisy to extend with custom phases, and the existing `xcodebuild test` invocation in `make test` already runs `SkymarshalTests`. Putting the guard in XCTest costs zero ceremony.

**Initial verification (today, before writing the test):** repo-wide grep already returns **zero** matches outside the allowed list. The test exists to keep it that way.

---

## 4) Per-view diff sketches

Each entry: file, the visible change, the before snippet, the after snippet, and the accessibility / Dynamic Type implications.

> **Notation:** these are *sketches*, not literal patches. The line numbers are
> from current HEAD; they will drift the moment touch-ups land. Read with the
> file open beside this doc.

### 4.1 `ios/Skymarshal/UI/ContentListView.swift` — `ContentRow` (row 1)

**Site:** `ContentRow > VStack > HStack(spacing: 6)` and the metric `HStack(spacing: 14)`.

Before (current — lines ~636–675):

```swift
Text(item.contentType.label.uppercased())
    .font(.caption2.weight(.semibold))
    .tracking(0.4)
    .foregroundStyle(.secondary)
…
Text(date, style: .date)
    .font(.caption2)
    .foregroundStyle(.tertiary)
…
HStack(spacing: 14) {
    metric(count: item.likeCount, symbol: "heart")
    metric(count: item.repostCount, symbol: "arrow.2.squarepath")
    metric(count: item.replyCount, symbol: "bubble.left")
}
.font(.caption2)
.foregroundStyle(.secondary)
```

After:

```swift
Text(item.contentType.label.uppercased())
    .font(Theme.Mono.kicker(11))
    .tracking(0.15)
    .foregroundStyle(.secondary)
…
Text(date, style: .date)
    .font(Theme.Mono.tabular(11))
    .foregroundStyle(.tertiary)
…
HStack(spacing: 14) {
    metric(count: item.likeCount, symbol: "heart")
    metric(count: item.repostCount, symbol: "arrow.2.squarepath")
    metric(count: item.replyCount, symbol: "bubble.left")
}
.font(Theme.Mono.tabular(11))
.foregroundStyle(.secondary)
```

**Accessibility:** `Theme.Mono.*` uses `relativeTo:` Dynamic Type categories — at AX5 the row grows accordingly. `.tracking(0.15)` is reduced from 0.4 because Plex Mono SemiBold has narrower glyph spacing than SF Pro caps; verify at AX5 that the kicker still doesn't wrap. **`accessibilityLabel` left unchanged** (`metric(...)` already supplies one).

**Single-line risk:** the "POSTS · May 14, 2026" header is the most exposed because the kicker + date sit in the same `HStack`. If at AX5 they overflow, drop the bullet and let the date wrap to a second line — handled by the existing `VStack(alignment: .leading)`.

### 4.2 `ios/Skymarshal/UI/ContentListView.swift` — subhead (row 1)

**Site:** Lines ~158–171, the "1 visible · avg engagement 0" strip behind `contentPowerToolsExpanded`.

Before:

```swift
HStack {
    Text("\(filteredItems.count) visible")
    Text("·").foregroundStyle(.tertiary)
    Text(String(format: "avg engagement %.0f", filteredAverageEngagement))
}
.font(.caption2)
.foregroundStyle(.secondary)
```

After:

```swift
HStack {
    Text("\(filteredItems.count) visible")
    Text("·").foregroundStyle(.tertiary)
    Text(String(format: "avg engagement %.0f", filteredAverageEngagement))
}
.font(Theme.Mono.tabular(11))
.foregroundStyle(.secondary)
```

**Accessibility:** preserved by the existing `.accessibilityElement(children: .combine)` and `.accessibilityLabel(...)`.

### 4.3 `ios/Skymarshal/UI/ScanSummaryStrip.swift` (row 1)

**Site:** Private `Pill` struct `content` body (lines ~125–134).

Before:

```swift
Text(value)
    .font(.caption.weight(.semibold).monospacedDigit())
…
Text(label)
    .font(.caption2)
```

After:

```swift
Text(value)
    .font(Theme.Mono.tabular(13))
    .foregroundStyle(isActive ? .white : color)
…
Text(label)
    .font(Theme.Mono.caption(10))
    .foregroundStyle(isActive ? .white.opacity(0.85) : .secondary)
```

**Accessibility:** `softLabel(for:value:)` and `.accessibilityHint` paths unchanged. VoiceOver order preserved.

**Optional follow-up (v1.0.2):** swap the entire `Pill` for `ScopePill` to dedupe. Held until v1.0.2 because `ScanSummaryStrip`'s pill has the `isActive` toggle state which `ScopePill` doesn't model yet. v1.0.2 introduces `ScopePill.Emphasis.active(Color)` for this.

### 4.4 `ios/Skymarshal/UI/AccountRow.swift` (row 1)

**Site:** Handle line + metric row (lines ~36 and ~56–67).

Before:

```swift
Text("@\(account.handle)")
    .font(.caption2.monospaced())
…
HStack(spacing: 14) {
    metric("\(short(account.profile.followersCount))", "person.fill")
    metric("\(short(account.profile.followsCount))", "person.crop.circle.badge.plus")
    metric(ratioLabel, "arrow.left.arrow.right")
    Spacer(minLength: 4)
    Text(account.influenceTier.label.lowercased())
        .font(.caption2.monospaced())
        .foregroundStyle(.tertiary)
}
.font(.caption2)
.foregroundStyle(.secondary)
.lineLimit(1)
```

After:

```swift
Text("@\(account.handle)")
    .font(Theme.Mono.caption(11))
…
HStack(spacing: 14) {
    metric("\(short(account.profile.followersCount))", "person.fill")
    metric("\(short(account.profile.followsCount))", "person.crop.circle.badge.plus")
    metric(ratioLabel, "arrow.left.arrow.right")
    Spacer(minLength: 4)
    Text(account.influenceTier.label.lowercased())
        .font(Theme.Mono.caption(11))
        .foregroundStyle(.tertiary)
}
.font(Theme.Mono.tabular(11))
.foregroundStyle(.secondary)
.lineLimit(1)
```

**Accessibility:** Row min-height 56pt preserved; Dynamic Type still flows. Confirm at AX5 that the metric line still single-lines on iPhone SE-class — Plex Mono is slightly wider than SF Pro caption2 at the same point size; the `Spacer(minLength: 4)` should absorb it.

### 4.5 `ios/Skymarshal/UI/AccountRow.swift` — `BotScoreBadge` (row 2)

Replace the inline implementation with a `ScopePill` wrapper. The badge keeps its
"`ant.fill` + score" semantic — `ScopePill` accepts a leading `Image` parameter
(add to component contract in §3.4).

Before:

```swift
HStack(spacing: 2) {
    Image(systemName: "ant.fill")
        .font(.caption2.weight(.semibold))
        .symbolRenderingMode(.monochrome)
    Text("\(Int(score * 100))")
        .font(.caption2.weight(.semibold).monospacedDigit())
}
.foregroundStyle(color)
.padding(.horizontal, 6).padding(.vertical, 2)
.background(Theme.chipTint(color), in: .capsule)
.accessibilityLabel("Automation signals: \(Int(score * 100)) of 100")
```

After:

```swift
ScopePill(
    value: "\(Int(score * 100))",
    label: nil,
    emphasis: score >= 0.6 ? .danger : (score >= 0.3 ? .caution : .muted),
    leading: Image(systemName: "ant.fill")
)
.accessibilityLabel("Automation signals: \(Int(score * 100)) of 100")
```

**Note on radius:** the badge moves from `.capsule` to `.rect(cornerRadius: 3)`. That's the intentional silhouette change.

### 4.6 `ios/Skymarshal/UI/LoadProgressBanner.swift` (row 1)

**Site:** Lines ~37–47, the "11,074 loaded · scanning posts" line.

Before:

```swift
Text(progress.itemsLoaded.formatted())
    .font(.subheadline.weight(.semibold).monospacedDigit())
Text("loaded")
    .font(.subheadline)
…
Text("scanning \(progress.phase.rawValue.lowercased())")
    .font(.subheadline)
```

After:

```swift
Text(progress.itemsLoaded.formatted())
    .font(Theme.Mono.tabular(15))     // Medium @ 15 — emphasis
    .foregroundStyle(.primary)
Text("loaded")
    .font(Theme.Mono.body(13))
…
Text("scanning \(progress.phase.rawValue.lowercased())")
    .font(Theme.Mono.body(13))
```

**Accessibility:** `.accessibilityElement(children: .combine)` + combined label unchanged.

`LoadProgressBannerLite` (in `StatusBanners.swift`) gets the same Plex Mono treatment on its title text — same trivial swap.

### 4.7 `ios/Skymarshal/UI/VisualizationHubView.swift` — status chips (row 2)

**Site:** `hubRow` private function (lines ~58–77), the `"Unknown"` / `"Partial"` chip.

Before:

```swift
Text(completeness)
    .font(.caption.weight(.semibold))
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Theme.chipTint(Theme.scope), in: .capsule)
```

After:

```swift
ScopePill(
    value: completeness.uppercased(),
    label: nil,
    emphasis: completeness == "Unknown" ? .muted : .scope
)
```

**Accessibility:** parent `.accessibilityElement(children: .combine)` + `.accessibilityLabel("\(title). \(subtitle). Data completeness \(completeness).")` unchanged. `ScopePill` defaults to caps internally — the `.uppercased()` on the value is for the visual silhouette, not accessibility (VO will speak from the parent's combined label).

The same swap applies to the three `LabeledContent("Completeness", value: …)` rows in the detail screens. Use `ScopePill` as the trailing `value:` representation.

### 4.8 `ios/Skymarshal/UI/LoginView.swift` — "Sign in" CTA (row 5)

**Site:** Lines ~88–104.

Before:

```swift
Button {
    Task { await model.login(handle: handle, password: appPassword) }
} label: {
    HStack {
        if model.isLoading {
            ProgressView().controlSize(.small)
        }
        Text(model.isLoading ? "Signing in…" : "Sign in")
            .font(.headline)
            .frame(maxWidth: .infinity)
    }
    .padding(.vertical, 4)
}
.buttonStyle(.borderedProminent)
.disabled(!canSubmit)
```

After:

```swift
Button {
    Task { await model.login(handle: handle, password: appPassword) }
} label: {
    HStack {
        if model.isLoading {
            ProgressView().controlSize(.small)
        }
        Text(model.isLoading ? "Signing in…" : "Sign in")
            .frame(maxWidth: .infinity)
    }
}
.buttonStyle(SaturnButton(emphasis: .primary))
.disabled(!canSubmit)
.accessibilityIdentifier("login_signInButton")    // already implicit via label
```

**Accessibility:** The `Text("Sign in")` is the VoiceOver label. `app.buttons["Sign in"]` in `AccessibilityRegressionTests.test_launchAtAX5_loginView_inputsReachable_andNotTruncated` keeps working — verified by re-reading the test (no change required).

**Dynamic Type:** `SaturnButton` uses `Theme.Mono.body(15)` with `relativeTo: .body`, so AX5 still scales the label.

### 4.9 `ios/Skymarshal/UI/BluescreenView.swift` — empty state CTA (row 5)

**Site:** Lines ~232–239.

Before:

```swift
ContentUnavailableView {
    Label("Scan your follow list", systemImage: "scope")
} description: {
    Text("Pull up everyone you follow and score each one for bot patterns, inactivity, and mutuality.")
} actions: {
    Button("Begin scan") { model.startScan() }
        .buttonStyle(.borderedProminent)
}
```

After:

```swift
ContentUnavailableView {
    Label("Scan your follow list", systemImage: "scope")
} description: {
    Text("Pull up everyone you follow and score each one for bot patterns, inactivity, and mutuality.")
} actions: {
    Button("Begin scan") { model.startScan() }
        .buttonStyle(SaturnButton(emphasis: .primary))
}
```

**Accessibility:** label unchanged. `ContentUnavailableView` already supplies the
"Scan your follow list — Pull up… — Begin scan" combined accessibility tree.

---

## 5) Test additions (v1.0.1)

### 5.1 Extend `AccessibilityRegressionTests`

Add two new tests adjacent to `test_launchAtAX5_loginView_inputsReachable_andNotTruncated`:

- `test_AX5_contentRow_kicker_andDate_doNotTruncate` — launch with `XCUIApplication.stubMinimalContentArgument` + AX5 environment, assert `app.staticTexts["POSTS"].exists` and the date `staticText` `exists`. Catches the Plex-Mono-is-wider regression at the largest Dynamic Type.
- `test_AX5_scopeTab_completenessPill_readsAsExpected` — launch with `-sm.feature.visualizationHub YES` + AX5, navigate to Scope, assert the completeness pill's accessibility label combines correctly under `ScopePill`.

No contrast assertions yet — the existing `Theme` tokens already clear WCAG 1.4.11; the new `Theme.Mono.*` is type, not color, so contrast is unchanged. Defer contrast snapshots to v1.0.2 when paper-bone backgrounds change the underlying canvas.

### 5.2 `TokenCoverageTests` — §3.5 above

Runs in the existing `SkymarshalTests` bundle. `make test` picks it up via the existing `xcodebuild test` invocation.

### 5.3 Re-run `StyleDiagnosisCapture` after the v1.0.1 work

Same command as the diagnosis cycle:

```bash
cd ios
xcodebuild test -scheme Skymarshal \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SkymarshalUITests/StyleDiagnosisCapture \
  -resultBundlePath /tmp/skymarshal-style-restyle-v101.xcresult
```

**Acceptance — eyeball pass:**

- Screenshot 2 (Content tab): the "POSTS" kicker reads as Plex Mono SemiBold, the date `· May 14, 2026` reads as Plex Mono tabular, and the metric counts read as Plex Mono Medium tabular.
- Screenshot 4 (Scope tab): the `Unknown` / `Partial` chips are 3px-radius rectangles with Plex Mono caps text — NOT iOS-style capsules with SF Pro.
- Screenshot 1 (Login): the "Sign in" button has a sharp 3px corner, paper-toned fill, and a 1px ink-toned border — NOT a continuous blue capsule.
- Screenshot 3 (Followers empty state): same SaturnButton on "Begin scan".

### 5.4 Manual smoke — `Theme.audit()` crash test (DEBUG)

Temporarily delete one entry from `UIAppFonts` in `project.yml`, regenerate, run in DEBUG, confirm the precondition fires before the LoginView paints. Restore the entry. This is a one-time smoke; do not check the broken spec in.

---

## 6) Kill criteria + rollback

### 6.1 Ship-blockers (must hold v1.0.1)

- **`UIFont.fontNames(forFamilyName: "IBM Plex Mono")` returns empty at launch.** Means the OTFs didn't end up in the Copy Bundle Resources phase. Don't ship until `Theme.audit()` passes in DEBUG and Release.
- **`Theme.Mono.tabular(...)` falls back to system font in RELEASE.** Indistinguishable from "fonts not bundled" in production. Test: `xcodebuild -configuration Release archive`, install over TestFlight, run on a physical iPhone 13 + iPhone SE, take screenshots, eyeball.
- **`TokenCoverageTests` fails on PR.** Means someone re-introduced a raw color literal outside `Theme*.swift`.
- **`AccessibilityRegressionTests` at AX5 fails on iPhone 17 simulator.** Means Plex Mono is wider than SF Pro at the same point size and broke a single-line constraint.

### 6.2 Pivot-trigger (do NOT ship; revert)

- AX5 + Plex Mono together breaks `ContentRow`'s single-line kicker layout AND `Theme.Mono.kicker(11) with relativeTo: .caption2` doesn't recover. Lower the kicker size to 10pt and re-test before considering Plex Mono in general unfit — but if 10pt also fails, this is the pivot.
- Real-device test on iPhone SE (1st gen 4-inch class) clips the LoadProgressBanner — Plex Mono Medium @ 15pt is too wide for that physical width. Solution: drop to `Theme.Mono.tabular(13)` for the banner only. If 13pt also clips, the pivot is to keep SF Pro on the banner and Plex Mono only on `ContentRow`.

### 6.3 Rollback plan

If we ship v1.0.1 to TestFlight and a soak surfaces a Plex Mono regression on a class of device we didn't catch:

1. Revert the two new files (`Theme+Fonts.swift`, `SaturnButton.swift`, `ScopePill.swift`, and the per-view diff sketches in §4). This is mechanically straightforward — every per-view change is a single `.font(...)` modifier swap.
2. Keep the OTFs in the bundle and `UIAppFonts` in the Info.plist. Removing them risks a second submission cycle for a one-line metadata change; leaving them costs ~600KB.
3. The diagnosis doc's screenshot harness verifies you're back to baseline — re-run `StyleDiagnosisCapture` and visually compare against the May 14, 2026 captures stashed at `/tmp/skymarshal-style-diagnosis.xcresult` (or wherever the workflow captures them next time).
4. Cut v1.0.2 from the rollback point. Do NOT stack v1.0.2's Saturn paper-bone work on top of an unhealed v1.0.1.

---

## 7) Sequencing across the two releases

### 7.1 v1.0.1 work order (smallest-risk-first)

1. **Font shipping.** Download IBM Plex Mono 6.4.0+ from `github.com/IBM/plex/releases`. Drop the three OTFs in `ios/Skymarshal/Resources/Fonts/`.
2. **`project.yml` Info.plist additions.** Add `UIAppFonts` array. Regenerate the Xcode project. Commit the spec change separately so it's reviewable in isolation.
3. **`app-store/LICENSE_FONTS.md`.** OFL attribution for IBM Plex Mono.
4. **`Theme.audit()` assertion.** Land before any font reference is added to a view — the assertion is the safety net for everything that follows.
5. **`Theme+Fonts.swift`.** `Theme.Mono.{kicker, body, tabular, caption}` helpers. Add the assertion verbatim from §2.7. Run the simulator once, confirm `UIFont.fontNames(forFamilyName:)` resolves the names the assertion expects.
6. **`SaturnButton.swift`** (with the shim for paper/hairline since `Theme+Saturn.swift` doesn't ship until v1.0.2).
7. **`ScopePill.swift`** (Plex-Mono-text rectangular chip).
8. **Per-view applications, one PR each** in the order:
    - `ContentRow.swift` kicker + date + metrics
    - `ContentListView.swift` subhead
    - `ScanSummaryStrip.swift` internal `Pill` text
    - `AccountRow.swift` handle + metric row
    - `LoadProgressBanner.swift` + `StatusBanners.swift` lite banner
    - `BotScoreBadge` → `ScopePill`
    - `VisualizationHubView.swift` chips → `ScopePill`
    - `LoginView.swift` "Sign in" → `SaturnButton`
    - `BluescreenView.swift` "Begin scan" → `SaturnButton`
9. **`TokenCoverageTests`.** Lands last in the v1.0.1 sequence so it doesn't bisect an in-flight per-view PR.
10. **Re-capture `StyleDiagnosisCapture`.** Visual delta check against May 14 baseline.
11. **Add the two new `AccessibilityRegressionTests`** (`test_AX5_contentRow_kicker_andDate_doNotTruncate`, `test_AX5_scopeTab_completenessPill_readsAsExpected`).
12. **Tag and submit.** Bump `MARKETING_VERSION` to `1.0.1`, `CURRENT_PROJECT_VERSION` to `5`. App Store description and "What's New" prose drafted separately (out of scope for this doc).

### 7.2 v1.0.2 gate

Do not start v1.0.2 work until:

- v1.0.1 has at least **one full TestFlight cycle** of physical-device soak.
- Plex Mono renders correctly on **iPhone 17** (Pro Max-class wide screen), **iPhone 13** (mid baseline), and **iPhone SE (3rd gen)** (4.7" — narrowest current iPhone, hardest Plex Mono target).
- No external tester crash report mentions font rendering, missing glyphs, or AX5 truncation.
- `Theme.audit()` has not fired in DEBUG during a developer's normal soak (the precondition is a real signal — if it ever fires, something is off in the bundle layout).

### 7.3 v1.0.2 work order

1. **Ship Fraunces OTFs** (Regular, Medium, SemiBold + matching italics if cycle 1 finds editorial use cases). Same shipping path as Plex Mono: `Resources/Fonts/`, `UIAppFonts` entry, OFL attribution appended to `app-store/LICENSE_FONTS.md`.
2. **Extend `Theme+Fonts.swift`** with `Theme.Display.{title, subhead, kicker}` wrapping `Font.custom("Fraunces-…", size:, relativeTo:)`.
3. **`Theme+Saturn.swift`.** Paper / inkSoft / muted / hairline tokens. Verify in DEBUG that the dynamic-provider light/dark resolves correctly with `xcrun simctl ui booted appearance`.
4. **Replace the `SaturnButton` shim.** Swap `Color(.systemBackground)` and `Color.primary.opacity(0.32)` for `Theme.paper` and `Theme.hairlineStrong`.
5. **Background swap.** Per-list site:
    - `ContentListView.List` → `.listRowBackground(Theme.paper).scrollContentBackground(.hidden)`
    - `BluescreenView.List` → same
    - `VisualizationHubView.List` → same
    - `LoginView.Form` → already `.scrollContentBackground(.hidden)`; just set the underlying `LoginBackground` to a paper-bone gradient instead of the `systemBackground → accentColor.opacity(0.08) → systemBackground` triple.
    - `AnalyticsInsightsView`, `AccountDetailView`, `PostDetailView`, `BackupRestoreView`, `AboutView`, `InteractionHistoryView`, `AdvancedSearchBuilderView` — six more list sites. Each gets the same two-modifier swap. Apply in a single PR titled "v1.0.2: paper-bone backgrounds across List sites" so the visual delta is reviewable in one screenshot pass.
6. **Fraunces on nav titles + hero headers.** Add `.toolbar { ToolbarItem(placement: .principal) { Text(...).font(Theme.Display.title(20)) } }` overrides for the `.large` titles that today read as Settings-app default. Apply to `ContentListView` ("My Content"), `BluescreenView` ("Followers"), `VisualizationHubView` ("Scope"), `AnalyticsInsightsView` section headers.
7. **Filter chip row.** `TypeChipsRow.swift` → typographic kicker tags ("▸ ALL · POSTS · REPLIES · REPOSTS · LIKES" with hairline-underline-on-active). Verify the picker semantics still work via `.searchScopes` binding.
8. **Toolbar icon swap.** Replace iOS 26 circle-behind-icon with `.toolbarRole(.editor)` + hairline-square frame. This is the lowest-priority v1.0.2 move because iOS 26 system rendering is fighty here — keep it as a stretch goal.
9. **Re-capture `StyleDiagnosisCapture`** post-v1.0.2.
10. **Update snapshot tests.** Add new `AccessibilityRegressionTests` for Fraunces nav-title legibility at AX5.

---

## 8) Estimated effort

Honest hours, not "could maybe be done in" hours. Assume one focused developer.

### v1.0.1

| Work item | Hours |
|-----------|------:|
| Font shipping (download, drop, OFL, `project.yml`, regenerate) | 0.75 |
| `Theme.audit()` assertion + smoke test | 0.5 |
| `Theme+Fonts.swift` | 0.5 |
| `SaturnButton.swift` (with shim) | 1.0 |
| `ScopePill.swift` (with leading-image parameter) | 0.75 |
| Per-view diff sketches (9 sites) — ~10 min average | 1.5 |
| `TokenCoverageTests` | 0.5 |
| `AccessibilityRegressionTests` extension (2 tests) | 0.75 |
| Re-capture `StyleDiagnosisCapture` + visual diff against baseline | 0.5 |
| TestFlight build + submission | 0.5 |
| **v1.0.1 total** | **~7.25 hours** |

(Diagnosis doc's "~3 hours of focused work, plus snapshot tests" estimate was optimistic by a factor of ~2.5×. The realistic number is ~7 hours once `Theme.audit()`, the SaturnButton shim, and font-naming verification are added in. Greybeard says: ship the honest number.)

### v1.0.2

| Work item | Hours |
|-----------|------:|
| Fraunces shipping + extend `Theme+Fonts` | 1.0 |
| `Theme+Saturn.swift` + dynamic-provider validation | 1.0 |
| Remove SaturnButton shim | 0.25 |
| Paper-bone background swap (10 list sites, single PR) | 2.0 |
| Fraunces on nav titles (4 sites) + AnalyticsInsights headers | 1.5 |
| `TypeChipsRow` → typographic kicker tags | 2.0 |
| Toolbar icon hairline-square swap | 1.5 (stretch; can defer to v1.0.3) |
| Re-capture `StyleDiagnosisCapture` + snapshot test updates | 1.0 |
| TestFlight build + submission | 0.5 |
| **v1.0.2 total** | **~10.75 hours** |

**Combined effort across both releases: ~18 hours.** That's two focused days, not one, and counts only implementation — does NOT count TestFlight soak time (where the v1.0.2 gate forces real calendar elapse).

---

## 9) What this plan DELIBERATELY does not change

Three things look like they ought to be in scope and are deliberately not.

### 9.1 The Liquid Glass `TabView` pill

`CLAUDE.md` is explicit: *"iOS 26 Liquid Glass is intentional on TabView. The floating pill tab bar at the bottom is system rendering when running on iOS 26 even with iOS 17 deployment target. Do NOT apply `.glassEffect()` to list rows / count pills — Liquid Glass is exclusively for the navigation layer."*

The diagnosis doc agrees and the cynic's counter-check explicitly clears it: the pill is recognizable as system rendering but only occupies ~10% of the screen. The other 90% is what makes every tab feel like another iOS Settings clone — that's what rows 1–7 fix.

### 9.2 The system `.searchable` field

`ContentListView` uses `.searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always))` and the binding feeds `pruneSelectionToVisible()` — the safety pin that protects users from bulk-deleting selected items they can no longer see after a search clears. Rolling our own search field would either re-implement that binding (cost) or break it (risk).

We don't have a *reason* to roll our own yet. The system field's only sin is that it looks like iOS Mail. That's a price worth paying to keep `pruneSelectionToVisible()` plumbed correctly.

### 9.3 DotBird hero + wordmark + tagline

`CLAUDE.md` brand voice rule: *"Air-traffic control for your Bluesky — spy-bird AppIcon + dot-matrix LoginView header + scope motif. Never replace."*

The diagnosis brand-load section confirms these are doing real work — they carry the screen identity-wise. Move #2 does NOT touch:

- The `DotBird` SF Image hero in `LoginView`.
- The `Text("Skymarshal")` wordmark at `.largeTitle .semibold`.
- The italic `Text("Air-traffic control for your Bluesky.")` tagline.
- The "Climb aboard" section header copy.
- The `EasterEgg` long-press path (accessibility-gated; load-bearing for the dot-matrix surface character).

What Move #2 *does* touch on `LoginView` is one button. The rest of the screen stays.

---

## Status

- [x] Move #1 — diagnose first ([`STYLE_DIAGNOSIS_2026-05-14.md`](STYLE_DIAGNOSIS_2026-05-14.md)).
- [x] Move #2 — Plex Mono + Saturn buttons on tabular surfaces (v1.0.1 — this plan §§2–6, 7.1). Delivered 2026-05-14, see [`screenshots/2026-05-14-roll2/`](screenshots/2026-05-14-roll2/) for the eyeball delta.
- [ ] Move #3 — paper-bone + Fraunces pass (v1.0.2 — this plan §7.3). Gate on one TestFlight soak cycle of Move #2.

### Move #2 delivery notes

- IBM Plex Mono 1.1.0 shipped (Regular/Medium/SemiBold) under SIL OFL 1.1.
  PostScript names resolved at runtime: `IBMPlexMono`, `IBMPlexMono-Medm`,
  `IBMPlexMono-SmBld` (the 6.0+ abbreviated spellings). `Theme.audit()`
  accepts the legacy long names too so a future Plex re-release that
  restores them won't fire the DEBUG precondition.
- `SaturnButton` ships with a one-line v1.0.2 shim documented inline:
  `Color(.systemBackground)` fill + `Color.primary.opacity(0.32)` border
  stand in for `Theme.paper` + `Theme.hairlineStrong` until Move #3 lands.
- `ScopePill` extended with an optional `leading: Image` parameter so
  `BotScoreBadge` could collapse into it without a second component.
- Marketing/`CFBundleVersion` not bumped in this commit. Build 5 / 1.0.1
  cuts in a separate `release: bump to build 5` commit when the next
  TestFlight upload is queued.

---

*Authored 2026-05-14. Author: Luke Steuber.*
