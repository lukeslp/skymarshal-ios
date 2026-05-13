# Design System: Skymarshal Ops Visual Language

**Version:** 1.0.0  
**Last Updated:** 2026-05-13  
**Platform:** iOS 17+ (SwiftUI)  
**Scope:** New parity + visualization surfaces

## 1) Design Intent

Skymarshal expansion adopts an **operations-console** aesthetic:
- Dark-first analytical canvas
- High-contrast semantic status colors from existing `Theme`
- Radar-like focus rings and restrained motion
- Legibility and trust over ornamental density

**App-wide UX charter (hierarchy, progressive disclosure, typography discipline):** see **[`CONTRIBUTOR_UX.md`](CONTRIBUTOR_UX.md) — UX charter** at the top of that file. This document owns **visualization** tokens and graph encoding; contributor SwiftUI checklist + Content power strip live in CONTRIBUTOR_UX.

## 2) Color Tokens

Use existing semantic tokens as source of truth:
- `Theme.danger`
- `Theme.caution`
- `Theme.warn`
- `Theme.scope`
- `Theme.success`
- `Theme.info`
- `Theme.like`

Add visualization-specific derived tokens (in a new standards file during implementation):
- `vizCanvas`: near-black neutral background
- `vizGrid`: low-contrast gridline
- `vizNodePrimary`: default node fill
- `vizNodeSelected`: selected node fill/outline
- `vizEdgeLow/Med/High`: weight bucket strokes
- `vizCompletenessPartial`: partial-data badge
- `vizCompletenessComplete`: complete-data badge

## 3) Typography

Maintain Dynamic Type compliant system fonts:
- Headings: `.title3`, `.headline`
- Data labels: `.subheadline`, `.footnote`
- Dense metrics: `.caption` with spacing safeguards

For visualization overlays:
- Use monospaced digits for metric values where rapid comparison matters.

## 4) Spacing + Density

- Base unit: 4pt.
- Standard surface padding: 16pt.
- Dense analytical cards: 12pt.
- Minimum hit target: 44pt.
- Graph legend/control spacing: 8pt between adjacent chips.

## 5) Components

### 5.1 Completeness Badge
- Required on all graph/heatmap entry cards and detail headers.
- States: `Partial`, `High confidence`, `Complete`.
- Includes last-sync timestamp.

### 5.2 Provenance Drawer
- Bottom sheet with data sources, date ranges, and unresolved gaps.
- Must be one tap from every visualization.

### 5.3 Risk Marker Chip
- Visual cue for destructive or high-impact subsets.
- Uses `Theme.danger`/`Theme.warn`; never color-only (icon + text).

### 5.4 Query Token Chip
- Distinct style per token class: required, excluded, phrase, subject, type, date.
- Parse-invalid token shows error state with assistive message.

## 6) Motion + Interaction

- Centralized motion gate: `ReduceMotion.shouldReduce(systemReduceMotion:)`.
- Default graph transitions:
  - Fade + slight scale for focus changes.
  - No large pan/zoom animation under reduced motion.
- Radar sweep accent:
  - Optional ambient pulse in hub header only.
  - Must disable under reduced motion.

## 7) Visualization Encoding Rules

- Never rely on color alone:
  - Edge type = color + dash pattern.
  - Node status = color + icon glyph.
  - Heat intensity = color + numeric label.
- Provide legend and textual summary on each visualization screen.
- Limit initial node count; use progressive reveal to preserve performance.

## 8) Accessibility Requirements

- VoiceOver:
  - Node: role, handle, degree, flags.
  - Edge: relationship type + weight summary.
  - Heatmap cell: hour/day/value spoken label.
- Dynamic Type:
  - Legends wrap safely, no clipped chips.
- Contrast:
  - Minimum WCAG 1.4.11 non-text contrast for all status indicators.
- Motor accessibility:
  - Alternate list/table mode for graph selections.

## 9) Performance + Rendering Guidance

- Render from materialized snapshots, not live recompute on every gesture.
- Debounce expensive relayout operations.
- Keep predictable node caps by device class.
- Profile body re-render counts for graph-heavy screens.

## 10) Implementation Checklist

- Add visualization token set to core standards.
- Build reusable completeness/provenance components.
- Build query token chip system with validation states.
- Add graph/list mode toggle to each visualization screen.
- Add AX labels/tests and reduced-motion tests.
- Add snapshot/perf tests for 10k and 50k fixture accounts.
