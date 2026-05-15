# Aesthetic direction B — Paper zine / broadsheet

**Date:** 2026-05-15 · **Codename:** `riso_scope`

## Thesis

Skymarshal is a **personal archive tool** — present it as a **printed ops zine**: warm paper, ink, halftone scope motif, torn edges, serif **display** for titles and mono for **telemetry**. Feels human and editorial (Are.na / Read.cv energy) while keeping destructive flows **literal** and calm.

## Palette (hex)

| Token | Hex | Use |
|-------|-----|-----|
| `paper` | `#F4F0E6` | Primary background (light) |
| `ink` | `#1A1A1A` | Primary text |
| `margin_rule` | `#C4B8A8` | Hairlines |
| `ribbon` | `#B23A3A` | Accent / destructive attention (maps to `Theme.danger` tone) |
| `night_paper` | `#2A2824` | Dark mode “newsprint” |

## Type stack

| Role | Font | Fallback |
|------|------|----------|
| Display / section titles | **Fraunces** Soft / Regular | Georgia |
| Body | SF Pro Text | — |
| Metrics / handles | IBM Plex Mono | SF Mono |

Bundle Fraunces under **OFL** (same discipline as Plex).

## Swift pseudocode — `LoginView`

```swift
ZStack {
    PaperNoiseTexture().ignoresSafeArea() // subtle PNG or procedural
    VStack(spacing: 24) {
        Text("Skymarshal").font(.custom("FrauncesSoft-Regular", size: 34, relativeTo: .largeTitle))
        Text("Air-traffic control for your Bluesky").font(.subheadline).foregroundStyle(.secondary)
        // dot-matrix bird stays as halftone-tinted asset
        SaturnButton(emphasis: .primary) { Text("Sign in") } // restyle fill to paper + ink border
    }
}
```

## Swift pseudocode — `ContentListView` header

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("My Content").font(Fraunces.display(28))
    HStack {
        Text("ISSUE \(Date().formatted(.dateTime.month().day()))")
            .font(Theme.Mono.caption(10))
        Spacer()
        Text(model.currentHandle ?? "").font(Theme.Mono.caption(11))
    }
    .foregroundStyle(.secondary)
    TypeChipsRow(...) // chips as **label tags** with torn-paper mask (small path) or 3pt radius + margin_rule stroke
}
.padding(.bottom, 12)
.overlay(alignment: .bottom) { Rectangle().fill(Color.hex("margin_rule")).frame(height: 1) }
```

## Swift pseudocode — tab bar

System `TabView`; use **scrollEdgeAppearance** / `toolbarBackground(.visible, for: .tabBar)` with paper-tinted material — **avoid** row-level glass. Tab labels: Fraunces for “Content” / “Followers” at **small caps** is risky at size — prefer **SF symbols + mono caption** for tabs, Fraunces only in nav titles.

## Concrete failure mode

**Visual noise vs. density:** halftone + texture + Fraunces competes with **filter chips + metrics** — the UI becomes **busy** faster than brutalist or cinematic. **Mitigation:** texture only on **login** + **empty states**; lists stay flat paper.

## Effort (honest)

| Tier | Scope |
|------|--------|
| M | Fraunces bundle + Theme + Login + nav titles |
| L | Texture pipeline + chip redesign + dark “newsprint” |
