# Style diagnosis — 2026-05-14

**Purpose:** Move #1 of the visual-restyle plan: before touching tokens or fonts,
look at every primary surface and label what reads as "default iOS" versus
what reads as "Skymarshal." Output of this doc decides whether to proceed
with the Saturn-token + IBM Plex Mono pass (Move #2 + #3) or redirect.

**How it was captured:** [`ios/SkymarshalUITests/StyleDiagnosisCapture.swift`](../ios/SkymarshalUITests/StyleDiagnosisCapture.swift)
walks the four primary surfaces on a stub fixture and saves PNGs as `XCTAttachment`
with `.keepAlways`. To re-run:

```bash
cd ios
xcodebuild test -scheme Skymarshal \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SkymarshalUITests/StyleDiagnosisCapture \
  -resultBundlePath /tmp/skymarshal-style-diagnosis.xcresult
```

Screenshots extract to `/tmp/skymarshal-screenshots/` (intentionally outside the
repo — they're research artifacts, not source).

---

## 01 — LoginView (signed-out cold start)

**Brand-load (the parts that work):**

- **DotBird dot-matrix hero.** Reads as ATC scope / radar / surveillance bird in
  one second. Distinctive in the App Store top-of-listing thumbnail.
- **"Skymarshal" wordmark** in bold SF Pro at hero size. Wordmark identity is fine.
- **"Air-traffic control for your Bluesky." tagline.** Locks the metaphor instantly.
- **"Climb aboard"** label above the inputs. On-voice.

**Default-iOS markers (the parts that look like every other app):**

- White `Form { Section }` card stack with rounded corners and hairline group
  separators. Identical to the Settings.app password-entry card.
- "yourname.bsky.social" placeholder is system gray SF Pro — the same placeholder
  treatment Mail uses for an empty To: field.
- The disabled "Sign in" pill button is pure `.borderedProminent` with a system
  capsule shape — generic iOS CTA.
- "Open Bluesky settings" link in default tint blue. No Skymarshal blue token used.
- Soft cool-gray background. The system `Form` background; not paper-bone, not
  Theme.scope-tinted.

**Hot takes:**

- The brand DOES carry the screen (the bird + wordmark are doing real work).
- But everything below the wordmark could be from any 2023-era SwiftUI tutorial.

---

## 02 — Content tab (with stub fixture)

**Brand-load:**

- **"POSTS" kicker** on the ContentRow uses caps + tracking — the closest thing
  shipped today to a Saturn / Swiss kicker. Has the type-icon badge in scope-blue
  next to it. ★ This is the row that already wants Plex Mono.
- **Heart / repost / reply icons** in the engagement strip. Functional.
- **Scope target icon in the Scope tab button** of the floating pill.

**Default-iOS markers:**

- **Nav title "My Content"** — pure SF Pro semibold black, inline display.
  Generic. (Could be "Mail / Inbox / Notes / Reminders.")
- **Search bar** — pure system `.searchable` rounded gray pill. Identical to
  Mail's mailbox search.
- **Filter row (`All`, `Posts`, `Replies`, `Reposts`)** — system `Picker` with
  bordered style. Gray fill, system tint blue on active. This row is the single
  biggest "default iOS" offender on this screen — reads exactly like the
  Mail/Photos filter strip.
- **"Select" link** in default tint blue. Inherits the system multi-select
  pattern verbatim.
- **"1 visible · avg engagement 0"** subhead in SF Pro gray secondary. Could
  be tabular Plex Mono.
- **Account icon + ellipsis** in the nav bar use the iOS 26 "circle-behind-icon"
  toolbar style introduced in Mail/Calendar. Pure system.
- **Liquid Glass floating TabView pill.** Intentional per CLAUDE.md and locked-in
  — this stays as-is. But the pill IS the most visually prominent piece of system
  chrome on the screen.
- **Hairline row separator** below the engagement strip — system `List` separator
  in `.separator` UIColor.

**Hot takes:**

- The ContentRow has good bones — the "POSTS" kicker just needs Plex Mono
  + the date `· May 14, 2026` to go tabular.
- The filter chip row is the worst offender on this screen. Replacing it with
  typographic kicker tags (▸ ALL / POSTS / REPLIES with hairline-underline-on-active,
  per the dreamer Swiss guide) would change the silhouette dramatically.
- Background is the system pale-gray. Paper-bone would make this screen
  read as "research notebook," not "Settings list."

---

## 03 — Followers tab (Bluescreen empty state)

**Brand-load:**

- **Scope target icon as the hero** of the empty state. Strong — the scope
  motif IS the brand and using it here is right.
- **"Scan your follow list"** headline in SF Pro Bold. Copy is good.
- **Subhead** — "Pull up everyone you follow and score each one for bot
  patterns, inactivity, and mutuality." On-voice.

**Default-iOS markers:**

- **Nav title "Followers"** — same SF Pro inline as Content. Generic.
- **"Begin scan" CTA** — pure `.borderedProminent` capsule in default tint blue.
  This is the iconic iOS sign-in / continue button. Reads as "iOS app first
  launch screen." Generic.
- **Search field "Search handle or name"** — same system pill as #2.
- **Scope target glyph in the nav bar** — wrapped in the iOS 26 circle-behind-icon
  toolbar style. The icon itself is right; the chrome around it is generic.
- **Liquid Glass pill.** Same as #2.

**Hot takes:**

- This is the screen most damaged by the system `.borderedProminent` button.
  "Begin scan" in a Saturn-style sharp-3px-radius button with paper-bone fill
  and ink-black 1px border would feel completely different — operational, not
  consumer-app-onboarding.
- Empty state composition is good; replace the button chrome and add a
  Plex Mono kicker ("READY TO SCAN ▸") and this becomes ours.

---

## 04 — Scope tab (VisualizationHub list)

**Brand-load:**

- **"Account graph / Interaction graph / Timeline heatmap"** — the three-card
  IA is good. Honest naming.
- **Scope target icon in TabView.** Good.

**Default-iOS markers:**

- **"Scope" large nav title** — pure SF Pro Bold black, `.large` display mode.
  Identical to Settings.app section pages. **This is the most "default iOS"
  surface in the app — Settings.app down to the pixel.**
- **"Visualizations" subhead kicker** in SF Pro gray. Could be Plex Mono caps.
- **Card stack with three rows + chevron disclosure.** Exact Settings.app /
  Reminders list / Notes folder list pattern. White rounded card on pale-gray
  background, hairline separators between rows, right-chevron at each row end.
- **"Unknown" / "Partial" status pills** in subtle tint-blue background.
  Identical to iOS Settings update-status chips. Should be Theme-tinted
  with Plex Mono caps text.
- **Footer disclaimer** "Coverage is partial until every relationship is
  materialized. Nothing here leaves your device." — SF Pro gray secondary.
  Voice is right, type is generic.

**Hot takes:**

- This screen is the strongest argument for the Saturn pass: replace the white
  rounded card with paper-bone surface + 1px ink hairlines (no card outline,
  just the row separators), put "VISUALIZATIONS" in Plex Mono caps as a kicker,
  status pills in Plex Mono Mini-caps. The IA stays identical; only chrome
  changes.

---

## Cynic's counter-check

> "What if it's just the Liquid Glass pill that's bothering you, and the rest
> is actually fine?"

**Answer from the evidence: no.** The pill is recognizable as iOS 26 system rendering
(and is intentional per CLAUDE.md "lean in, don't override"), but it occupies ~10%
of the screen at the bottom. The other 90% — search bar, filter chips, nav title,
white rounded cards, hairlines, status pills, CTA buttons, default tint blue,
SF Pro everywhere — is what makes every tab read as "another iOS Settings-shaped app."

The pill is the smallest part of the problem. **Proceed.**

---

## Verdict

**Diagnosis confirmed: proceed with Move #2 and Move #3.**

Cheapest-first-strike candidates ordered by ratio of visual impact to implementation risk:

| # | Change | Surface | Files | Risk | Visible in |
|---|---|---|---|---|---|
| 1 | **Plex Mono on tabular numbers + timestamps** | ContentRow date + counts; "1 visible · avg engagement 0" subhead; ScanSummaryStrip; AccountRow ratio | `Theme+Fonts.swift` + 4 view files | low (font registration only) | #2 |
| 2 | **Status pills → Theme.muted + Plex Mono caps** | Scope row status, BotScoreBadge, LoadProgress | `ScopePill.swift` (new), VisualizationHubView, BluescreenAnalyzer surfaces | low | #4 |
| 3 | **Filter chip row → typographic kicker tags** | ContentListView filter row | ContentListView | medium (replaces `Picker`-style) | #2 |
| 4 | **Saturn paper-bone background + ink hairlines** | App-wide `.listRowBackground(Theme.paper)` + `.listRowSeparatorTint(Theme.hairline)` | `Theme+Saturn.swift` + 6 list sites | medium (test in Forced-Colors + Increase-Contrast) | #1, #2, #3, #4 |
| 5 | **`.borderedProminent` → Saturn button (sharp 3px, ink border, paper fill)** | "Sign in", "Begin scan", any other CTA | `SaturnButton.swift` (new), LoginView, BluescreenView | low | #1, #3 |
| 6 | **Fraunces variable serif on nav titles + headers** | All nav `.large` titles, BluescreenView "Scan your follow list" hero, AnalyticsInsights section headers | `Theme+Fonts.swift` + per-view font modifiers | medium (ship OTF, DEBUG-assert registration) | #1, #3, #4 |
| 7 | **Replace nav-bar toolbar circle-behind-icon with hairline-square icons** | ContentListView account+overflow, BluescreenView scope, all toolbars | toolbar modifiers | low | #2, #3, #4 |

**Order of operations (proposed):**

- **v1.0.1 (post-Build-4 TestFlight soak):** rows 1, 2, 5 from the table.
  All low-risk, font shipping limited to Plex Mono only. Plus Saturn buttons,
  no font surprises. Estimate ~3 hours of focused work, plus snapshot tests.
- **v1.0.2 (after one TestFlight cycle confirms Plex Mono renders on device):**
  rows 3, 4, 6, 7. The paper-bone background + Fraunces nav titles are the
  high-visual-impact changes; deferring them one cycle lets us catch any
  custom-font surprise (greybeard's concern) without bundling it with the
  auth-fix release.

**Kept off the list:** restyling the Liquid Glass TabView pill (intentional
system rendering), restyling the system `Search` field (loses `.searchable`
filter-bind behavior — defer until we have a reason to roll our own).

**Acceptance criteria for v1.0.1:**

- All four screenshots (re-captured by the same UITest) show Plex Mono on the
  numeric / timestamp / kicker sites.
- "Sign in" + "Begin scan" buttons render with Saturn chrome.
- Existing 185 tests still pass.
- Token-coverage XCTest (new) fails the build if grep finds `.red`, `.orange`,
  `.yellow`, or raw RGB literals outside `Theme*.swift`.

---

## Status

- [x] Move #1 — diagnose first (this document).
- [ ] Move #2 — Plex Mono + Saturn buttons on tabular surfaces (next).
- [ ] Move #3 — paper-bone + Fraunces pass (v1.0.2 candidate).
