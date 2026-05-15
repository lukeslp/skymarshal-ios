# Aesthetic direction A — Brutalist / CRT console

**Date:** 2026-05-15 · **Codename:** `radar_console`

## Thesis

Skymarshal is **air-traffic control for your Bluesky** — lean into a **dense, monochrome radar console**: amber or green phosphor on true black, no Liquid Glass on content chrome, typography that reads like a teletype. Plex Mono becomes the **hero** face; SF Pro disappears except where Apple HIG forces system chrome.

## Palette (hex)

| Token | Hex | Use |
|-------|-----|-----|
| `void` | `#000000` | App background |
| `phosphor` | `#FFB000` (amber) **or** `#33FF66` (green alt) | Primary text, borders |
| `phosphor_dim` | `#996600` / `#1A6633` | Secondary |
| `danger_glow` | `#FF3300` | Destructive only |
| `grid` | `#1A1A1A` | Subtle 8px CRT grid (Canvas / Metal optional later) |

All status semantics still map through **dynamic** `Theme` tokens — never raw `.red` on black (contrast + dark mode).

## Type stack

| Role | Font | Fallback |
|------|------|----------|
| Display / headers | IBM Plex Mono SemiBold | SF Mono |
| Body | IBM Plex Mono Regular | SF Mono |
| Tabular metrics | IBM Plex Mono + `.monospacedDigit()` | — |

## Swift pseudocode — `LoginView`

```swift
ZStack {
    Color.black.ignoresSafeArea()
    CRTScanlines().opacity(0.04) // optional Metal later
    VStack(spacing: 20) {
        Text("SKYMARSHAL").font(Theme.Mono.kicker(22)).foregroundStyle(Color(hex: phosphor))
        // dot-matrix header stays; tint phosphor
        SecureField("APP PASSWORD", text: $appPassword)
            .font(Theme.Mono.body(15))
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(Color(hex: phosphor), lineWidth: 1))
        Button("AUTHENTICATE") { ... }
            .buttonStyle(BrutalistBezel()) // sharp rect, inset shadow
    }.padding(24)
}
```

## Swift pseudocode — `ContentListView` header strip

```swift
VStack(spacing: 0) {
    HStack {
        Text(model.currentHandle ?? "—").font(Theme.Mono.caption(11))
        Spacer()
        Text("MODE: READ/WRITE").font(Theme.Mono.caption(10))
    }
    .padding(.horizontal, 8).padding(.vertical, 4)
    .background(Color(hex: grid))
    TypeChipsRow(...) // restyle chips as segmented **blocks** with 0pt corner radius
}
```

## Swift pseudocode — tab chrome

Keep **system** `TabView` for accessibility + state restoration; replace only **labels**: icon stays SF Symbol in **monochrome** `.foregroundStyle(phosphor)`; title string uses Plex Mono caption. **Do not** wrap rows in `.glassEffect()` (project rule).

## Concrete failure mode

**WCAG + App Review legibility:** pure phosphor-on-black fails **1.4.3 Contrast (Minimum)** for small text unless tuned; **AX5 Dynamic Type** with mono-only hierarchy becomes unreadable. **Mitigation:** keep a **high-contrast alternate** theme flag; cap mono sizes; reserve Fraunces or SF Pro **only** for legal / destructive sheets.

## Effort (honest)

| Tier | Scope |
|------|--------|
| M | New `Brutalist` theme namespace + Login + list headers |
| L | Full chip/toolbar/menu restyle + snapshot tests |
