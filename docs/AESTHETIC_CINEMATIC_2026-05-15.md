# Aesthetic direction C — Cinematic / spatial OLED

**Date:** 2026-05-15 · **Codename:** `vector_night`

## Thesis

Skymarshal is **precision tooling** with a **premium consumer** shell: deep OLED black, **electric blue → magenta** gradient identity (distinct from default `.tint`), large display type, generous vertical rhythm, **soft glass only on nav cards** — not on every list row (per project guardrails).

**Corner radius:** keep **6–10pt** on cards, fields, and primary CTA — avoid 16–20pt “consumer soft” unless the surface is a full-bleed hero. Tab chrome can follow system `TabView`; custom tab strips use the same tight radius, not pill stadiums.

## Palette (hex)

| Token | Hex | Use |
|-------|-----|-----|
| `void` | `#000000` | Base |
| `elev_1` | `#121218` | Card |
| `accentA` | `#3D7CFF` | Gradient start |
| `accentB` | `#C44CFF` | Gradient end |
| `starfield` | `#FFFFFF` at 6% | Specular noise overlay (optional) |

Map destructive / caution still through `Theme` — gradient never replaces **semantic** color.

## Type stack

| Role | Font | Fallback |
|------|------|----------|
| Display | SF Pro Rounded **or** custom geometric wordmark | — |
| Body | SF Pro Text | — |
| Metrics / tabs / chrome | SF Pro Text (system sans) + `tabular-nums` | Avoid monospace in dense or small UI — maximally readable for low vision and Dynamic Type. |

## Swift pseudocode — `LoginView`

```swift
ZStack {
    LinearGradient(colors: [.black, Color(hex: "elev_1")], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    VStack(spacing: 32) {
        Text("Skymarshal")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(LinearGradient(colors: [.hex("accentA"), .hex("accentB")], startPoint: .leading, endPoint: .trailing))
        // hero illustration: subtle glow behind dot-bird
        SecureField("App password", text: $appPassword)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        Button(action: login) {
            Text("Sign in").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "accentA"))
    }
    .padding(28)
}
```

## Swift pseudocode — `ContentListView` header

```swift
VStack(alignment: .leading, spacing: 6) {
    Text("My Content").font(.title.bold())
    Text(model.currentHandle ?? "")
        .font(Theme.Mono.caption(12))
        .foregroundStyle(.secondary)
}
.frame(maxWidth: .infinity, alignment: .leading)
.padding()
.background {
    RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial) // single “panel” — not per-row
}
```

## Swift pseudocode — tab bar

Rely on **iOS 26 Liquid Glass** system tab bar; set `accentColor` asset toward `accentA`. Optional: custom `ToolbarTabBarStyle` when API allows — **do not** fight system tab geometry.

## Concrete failure mode

**Brand washout:** Linear + Things/Linear vibes read as **generic “pro SaaS”** — loses spy-bird / ATC story unless typography and copy stay sharp. **Mitigation:** keep dot-matrix header + **mono metrics strip** as unmistakable Skymarshal markers.

## Effort (honest)

| Tier | Scope |
|------|--------|
| S | Gradient tokens + accent retune + Login |
| M | Panelized headers + list row spacing (no glass on rows) |
| L | Motion system (ReduceMotion-safe parallax on hero only) |
