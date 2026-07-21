# Guided Mode — Design Spec (Draft 1)

**Date:** 2026-07-20 · **Author:** Luke Steuber · **Status:** draft for discussion — sequenced after the a11y P0 branch lands
**Applies to:** Skymarshal iOS (native, `skymarshal-app`) and Skymarshal web (`skymarshal-web`, incl. Capacitor builds)

---

## 1. What this is

A **peer presentation layer**, not an accessibility ghetto. Guided mode restructures Skymarshal's existing task graph — *find → scope → confirm → wait* — into single-decision screens with few, large, iconic targets. It is chosen, never inferred; nothing is capability-gated; every guided flow has a "show me everything" exit into the full UI. Same engines underneath (search, deleteSafety/ContentService, Bluescreen scoring), different surface.

Who it serves, deliberately broadly: switch access and scanning users, dwell/eye-gaze users, people with tremor or limited precision, cognitive-load-sensitive users, anxious deleters, tired people on small phones. Marketing framing is "Guided," not "accessible" — the mode earns its keep for everyone.

## 2. Design principles

1. **One decision per screen.** A screen asks one question and offers 2–6 answers. If a step needs more than 6 options, the step is wrong — split it.
2. **Iconic, not symbolic.** No pictogram sets (PCS/ARASAAC etc. are out of scope). Every choice pairs a strong, literal icon (SF Symbols / lucide) with a short text label. Icon + word, always both, never icon alone. Icons are *doing* words where possible (magnifying glass = find, trash = delete, shield-check = keep).
3. **Big, forgiving, spaced.** Configurable target floor (see §4): 60pt default in guided mode, 88pt available. Inter-target spacing scales with target size — no adjacent-target penalty for tremor or scanning overshoot.
4. **Interaction-method flexible.** Tap, keyboard, switch scan, and dwell are peer input methods. The layout never assumes which one is driving (see §3). New methods slot in without redesigning screens — that flexibility is a core requirement, not a nice-to-have.
5. **Stable anchors.** Every guided screen carries the same three anchors in the same positions: **Back**, **Home**, **Next/primary action**. Progress in words ("Step 2 of 4"), never dots alone.
6. **Nothing timed against the user.** No auto-advance, no dismissal timers on informational content (already an app-wide baseline — defend it). Timing exists only *for* the user: arming windows, dwell thresholds — all generous, all configurable.
7. **Deliberate friction survives.** Guided mode never weakens the delete gates. It re-expresses them in plainly-activatable form (two-step arm/confirm, hold-to-confirm) — the P0.6 work is the seed and becomes the *only* gate style inside guided flows.

## 3. Interaction methods

The screen contract (few targets, large, stable anchors) is what makes all of these cheap to support on the same layouts:

- **Touch / pointer** — baseline. Large targets + `pointer: coarse` floors (web already enforces 44px globally; guided raises it).
- **Keyboard / switch scanning** — guided screens are shallow scan trees by construction (≤ 9 focusables incl. anchors). Group order: choices first, anchors last. This is where the P0.5 row-combining work pays off directly.
- **Dwell (exploratory, design-compatible from day one).** Reserve the affordance: every guided target must tolerate a hover/fixation-based activation with a visible dwell-progress ring (respecting reduce-motion: ring fills without pulse). Web first (pointer-based dwell is implementable in the page; eye-gaze rigs present as pointers — ties into the `eyegaze` repo experiments). iOS native dwell largely arrives free via system Dwell Control if targets are large and honest — our job is not to fight it.
- **Margins / edge zones (exploratory).** Screen edges and inter-content margins are the largest, easiest-to-hit real estate on any device. Candidate uses, kept optional and configurable: edge-hold = Back, bottom-margin bar = the primary action at full width, corner zones as scan-group shortcuts. Treat as a progressive enhancement slot — the layout reserves the space; features opt in later.
- **Parked for another conversation: timing-based selection.** The spinning-circle selector (rotating elements within circles, each labeled with a letter; activation by timing a single input against the rotation) is a genuinely interesting single-switch text-entry/selection mechanism — related to rotary/clock scanning. Explicitly out of scope for Guided mode v1; noted here so the idea isn't lost. If pursued, it would slot in as another peer input method under §3 without changing the screen contract — which is the test the flexibility requirement exists to pass.

## 4. Tier 1 — Access settings layer (build first, ships independently)

User-settable floors, useful in the *full* UI too, and the substrate guided mode runs on:

| Setting | Values | iOS | Web |
|---|---|---|---|
| Target size floor | Standard 44 / Large 60 / Max 88 | `@AppStorage("sm.targetFloor")` + environment key; rows/chips read it | `--target-scale` token + `data-access-mode` attr on root; extends the existing `--font-scale` / `.high-contrast` architecture |
| Max choices per screen | Full / 6 / 4 | drives filter surfaces toward preset buttons | same |
| Confirmation style | Typed / Two-step / Hold | surfaces the P0.6 alternatives as an explicit preference (AT-detection remains the automatic path) | same, via DestructiveConfirm |
| Extended timeouts | On/off (arming windows ×3, no short-lived UI) | app-side | app-side |
| Dwell activation | Off / On + threshold (0.8–3s) | defer to system Dwell Control; document it | pointer-dwell engine, progress ring |

Everything routes through the two token systems that already exist (Theme + ReduceMotion on iOS; OKLCH tokens + font-scale + high-contrast on web). No new styling architecture.

## 5. Tier 2 — Guided flows (the product)

Shell: full-screen card, question as heading, 2–6 choice cells in a grid (2×2 default, 2×3 max), anchor bar. iOS: new `GuidedShell` SwiftUI container; web: a `GuidedLayout` route wrapper. Both consume the same screen inventory:

**Flow A — Clean up old posts** (wraps search + delete)
1. "What do you want to clean up?" → Posts / Replies / Reposts / Likes
2. "How old?" → 7d / 30d / 90d / 1y / Older — big cells (this also retires the open timeframe-chips parity item)
3. "How do you want to review?" → **One at a time** / All together
4. One-at-a-time = the **delete parade** (v1.1 item `DeleteMode.INDIVIDUAL` — same feature, AAC-first): one post per screen, full text read-back, two giant choices — **Keep** / **Delete** — plus Undo-last in the anchor bar. Batch every ~25 through the standard confirm gate so the parade never silently accumulates an unbounded delete.
5. Confirm screen: plain sentence ("Delete 34 posts older than one year? This can't be undone."), wall-clock estimate, two-step arm/confirm as the gate.
6. Wait screen: progress in words, the 429 "pausing — Bluesky asked us to slow down" state (P1 fix) rendered large, Stop as a full-width margin-bar action.

**Flow B — Review my followers** (wraps Bluescreen/Patterns)
1. "What are you looking for?" → the four Cleanup presets as four big cells (they are already AAC-shaped answers; render `CleanupPreset.detail` as the cell's second line — the copy exists, currently unrendered)
2. Sensitivity as consequence language: "Careful — fewer flagged, fewer mistakes" / "Balanced" / "Broad — more flagged, may include real people"
3. One-account-per-screen review parade: avatar, name, plain-language flags (post-P2 rewrite), **Keep** / **Unfollow** / **Not a bot** (whitelist)
4. Same confirm/wait semantics as Flow A.

**Flow C — Delete by category** (Danger Zone, post-P0.1 engine)
1. "Delete all of which?" → Likes / Reposts / Follows / Blocks (posts deliberately excluded from one-tap-category in guided mode — route to Flow A)
2. Preflight screen: count + estimate in a sentence.
3. The strongest gate: two-step arm/confirm with the arming window, restated consequence.

## 6. Eventually: highly accessible chat (web)

Standing intent, recorded so the architecture leaves room: revive the earlier accessible-chat effort for web as a guided-mode citizen. Requirements sketch when it returns: conversation as a linear, fully keyboard/scan-traversable list; composer with large targets and optional dwell; message actions behind one disclosure (never hover-only); live-region discipline (announce new messages politely, never interrupt composition); TTS read-back of any message; works inside `GuidedLayout`. The §3 interaction contract and §4 settings are prerequisites it inherits for free — build them once, chat rides them. (The timing-selector idea, if it ever lands, is a candidate composer input here.)

## 7. Sequencing

1. **Now:** P0 branch lands (both repos) — row combining, dialog semantics, non-typing confirm paths, Danger Zone engine fix.
2. **Next:** Tier 1 settings layer, both platforms (small, independently shippable).
3. **Then:** Flow A on iOS as the proof (delete parade doubles as a planned v1.1 feature; Switch Control users concentrate on iOS; SwiftUI grid shell is cheap). Verification per the devkit matrix: Switch Control + VoiceOver device passes on the full flow, and user testing with switch users — this flow has exactly the complexity/consequence profile that demands it.
4. **Then:** port shell + Flow A to web (`GuidedLayout`), add dwell engine; Flows B–C on both.
5. **Later:** accessible chat (§6); margin-zone interactives as they prove out; timing-selector conversation when Luke wants it.

## 8. Open questions for Luke

- Entry point: onboarding offer ("Prefer a step-by-step experience?") vs. settings-only vs. both?
- Does Guided mode get its own app icon / launch argument for caregivers setting up a device?
- Parade batch size (25?) and whether Undo-last needs to survive app relaunch (breadcrumb already could carry it).
- Web dwell: build the pointer-dwell engine in-house or evaluate what the `eyegaze` repo experiments already yield?
