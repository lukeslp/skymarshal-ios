# UI/UX Specification: Skymarshal iOS Expansion

**Version:** 1.0.0  
**Last Updated:** 2026-05-12  
**Status:** Draft  
**Platform:** iOS 17+  
**Scope:** Advanced parity + visualization surfaces

## 1) Design Principles

1. **Safety over speed:** destructive actions must be explicit, previewable, and reversible when possible.
2. **Evidence over aesthetics:** visualizations must include confidence/completeness indicators.
3. **Progressive power:** novice users stay in simple flows; advanced tools are discoverable, not forced.
4. **Accessible by default:** every graph has VoiceOver narration and tabular equivalent.
5. **Operational clarity:** visual language feels like a modern flight console, not a social feed.

## 2) Brand Expression Direction

- **Visual tone:** midnight control-room with radar accents and high-contrast status states.
- **Memorable motif:** “scope sweep” interactions (subtle radial highlight and ring animations).
- **Interaction personality:** deliberate, precise, calm under load.

## 3) Information Architecture

**Navigation pattern:** existing 2-tab root remains, with added destinations.

```
Root
├── Content
│   ├── Search Results
│   ├── Advanced Search Builder (new)
│   ├── Delete Review Center (new)
│   ├── Backup Center (new)
│   └── Analytics + Timeline Heatmap (expanded)
├── Followers
│   ├── Bluescreen Filters
│   ├── Account Detail
│   └── Visualization Hub (new)
│       ├── Account Graph
│       ├── Interaction Graph
│       └── Post Graph
└── Shared
    ├── Operation Log (new)
    ├── Export/Import Sheets (expanded)
    └── About/Privacy
```

## 4) Screen Inventory

| Screen | Purpose | Priority |
|---|---|---|
| Advanced Search Builder | Build grammar-based query safely | P0 |
| Delete Review Center | Review and approve destructive batches | P0 |
| Visualization Hub | Entry point for graph/heatmap views | P0 |
| Account Graph | See account clusters/mutuals/bridges | P1 |
| Post Graph | See reply/repost/like pathways by post | P1 |
| Timeline Heatmap | Temporal concentration and anomaly spotting | P1 |
| Backup Center | Export/import/restore preview | P0 |
| Operation Log | Auditable destructive and restore history | P1 |

## 5) Core Screen Specs

### 5.1 Advanced Search Builder (P0)

**Purpose:** compose full parity query grammar without requiring raw syntax editing.

```
┌─────────────────────────────────────┐
│  Advanced Search          [Apply]   │
├─────────────────────────────────────┤
│  Query tokens                         │
│  [+ required] [- exclude] ["phrase"] │
│  [subject:handle] [type:likes]       │
├─────────────────────────────────────┤
│  Builder sections                    │
│  • Keywords                           │
│  • Content types                      │
│  • Subject filters                    │
│  • Date + engagement ranges           │
├─────────────────────────────────────┤
│  Preview                              │
│  1,244 matches · 2 warnings           │
│  [Run dry preview]                    │
└─────────────────────────────────────┘
```

**Interactions**
- Add/remove token chips.
- Toggle between Builder mode and Raw query mode.
- Live parse validation with inline error copy.
- Dry preview before applying.

**States**
- Empty builder state.
- Parse error state with exact token highlight.
- Valid state with estimated match count.

### 5.2 Delete Review Center (P0)

**Purpose:** review exactly what will be deleted before any write.

```
┌─────────────────────────────────────┐
│  Delete Review            [Continue] │
├─────────────────────────────────────┤
│  Scope lock: @ownerhandle            │
│  Total: 842 records                  │
│  Posts 120 | Replies 344 | Likes 288 │
├─────────────────────────────────────┤
│  Risk flags                          │
│  • Includes latest 7 days            │
│  • Includes high-engagement posts    │
├─────────────────────────────────────┤
│  Sample rows + reasons               │
│  [row] [matched by: token/date/type] │
└─────────────────────────────────────┘
```

**Interactions**
- Approve all, reject all, or split into reviewed batches.
- Export review set.
- Typed confirm required above threshold.

**States**
- Dry-run only mode.
- Awaiting typed confirm mode.
- In-progress mode with rate-limit pause visibility.

### 5.3 Visualization Hub (P0)

**Purpose:** central launchpad for all visual analysis surfaces.

```
┌─────────────────────────────────────┐
│  Visualizations                     │
├─────────────────────────────────────┤
│  [Account Graph]   completeness 82% │
│  [Post Graph]      completeness 61% │
│  [Interactions]    completeness 94% │
│  [Heatmap]         last sync 12m ago│
├─────────────────────────────────────┤
│  Filters: date, account, type, depth│
│  [Refresh slice] [Background sync]  │
└─────────────────────────────────────┘
```

**Interactions**
- Drill into graph view with retained filter context.
- Toggle summary/table/graph mode.
- Open data provenance sheet.

### 5.4 Account Graph (P1)

**Purpose:** identify clusters, bridges, and cleanup targets.

**Modes**
- Ego ring (default)
- Cluster map
- Bridge view (high-betweenness candidates)

**Required overlays**
- Completeness status.
- Edge type legend.
- Selection details panel with actionable next steps.

### 5.5 Post Graph (P1)

**Purpose:** understand how individual posts connect across replies/reposts/likes.

**Modes**
- Thread-centric
- Engagement pathway
- Author relationship overlay

### 5.6 Timeline Heatmap (P1)

**Purpose:** find temporal spikes for posting/engagement/interaction behaviors.

**Views**
- Hour x weekday matrix.
- Range compare (current vs prior period).
- Account-segmented rows.

### 5.7 Backup Center (P0)

**Purpose:** lifecycle management for export/import/restore with explicit risk communication.

**Critical flow**
- Select backup artifact.
- Run integrity check.
- Show restore diff preview.
- Require final confirmation.

### 5.8 Operation Log (P1)

**Purpose:** provide auditability and user confidence for destructive and restore workflows.

**Fields**
- Operation ID, timestamp, owner handle, scope summary, dry-run/write mode, outcome.

## 6) Interaction Patterns

- **Default mode:** guided builder controls with safe defaults.
- **Power mode:** raw grammar editor, persistent validation rail.
- **Graph interactions:** tap to inspect, pinch to zoom, lasso optional in advanced mode.
- **Long operations:** checkpointed progress with pause/resume semantics.

## 7) Accessibility Requirements

- VoiceOver labels for graph nodes/edges with concise semantic summaries.
- Tabular fallback for all graph surfaces.
- Heatmap non-color encoding (patterns + values).
- Dynamic Type support through AX5 on all planning-critical views.
- Reduced Motion branch for graph transitions and radar sweep effects.

## 8) Empty/Loading/Error Guidance

- **Empty:** explain why no data matches and offer one-step recovery.
- **Loading:** show current phase and checkpoint progress, not spinner-only.
- **Error:** plain-language reason + safe retry button + “do not retry writes” guidance where relevant.

## 9) Acceptance Criteria (UX)

- User can compose advanced query without typing raw syntax.
- User can confirm destructive scope before write with exact counts.
- Every visualization view exposes completeness and provenance.
- Every visualization has accessible non-graph equivalent.
- Backup restore always shows preview diff prior to confirmation.
