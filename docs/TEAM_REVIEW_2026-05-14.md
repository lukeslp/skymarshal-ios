# Team review — 2026-05-14

> **Status note (2026-05-16):** This review was written against a working `v1.0.1` label that was later retired. Nothing was ever released to the App Store under v1.0.1; the scope and fixes described here landed into the in-progress **v1.0.0 / build 5** (commit `9ca2e84` reverts the marketing version). Read the analysis below as historical record — substitute "v1.0.0 / build 5" wherever it says v1.0.1.

**Trigger:** Post-`a01876c` (visual restyle Move #2) council review.
**Scope:** `--full` (research + business + technical + skeptics + executive).
**Read-only:** No file edits attributed to the council. Janitor follow-ups land in
a separate commit (see "First three moves").

---

## Decision

Ship v1.0.1 to TestFlight after three small fixes. The pitch has legs at
**$2.99/mo or $19.99/yr** with a **$49.99 lifetime IAP** for the
"Curatorial Power-Poster" beachhead — but cynic's free-core-with-one-time-unlock
dissent is the strongest counterargument and survives breaker's attacks; keep it
on the kill-criteria table for the first 90 days.

---

## The pitch

**Product:** Skymarshal — native SwiftUI iOS app, content-management cockpit for
Bluesky. Authenticate, search-and-filter your own posts/replies/reposts/likes,
delete safely (typed-confirm at ≥100), score the accounts you follow for
automation signals + inactivity + mutuality with explicit dignity overrides.

**Audience:** *Curatorial Power-Poster* — writer / PM / ex-Twitter migrator with
5–50k Bluesky followers and a $30–80/yr craft-utility budget. The job-to-be-done
is **"audit my last three years of posts, make a deliberate prune"**, not
"nuke my account." Reeder / Things / Soulver / Working Copy is the adjacent
buying basket.

**Positioning:** *For Bluesky writers with audiences large enough to feel
exposed by their old posts, Skymarshal is the iOS-native content cockpit that
BskyDelete-on-the-web can't match — search-and-filter ergonomics, mission-control
typography, and a dignity-respecting bot scoring frame that other tools don't
attempt.*

**Monetization:** **$2.99/mo** subscription, **$19.99/yr** annual (33% discount),
**$49.99 lifetime IAP** as the third lane. Comp: BskyDelete is $10/mo web-only;
Circleboom is $13.99/mo enterprise. Skymarshal undercuts BskyDelete on monthly
and beats it on craft. The $49.99 lifetime IAP is the load-bearing SKU for the
buyer who reads "subscription" as friction.

**First three moves:**

1. **Bump `MARKETING_VERSION` to `1.0.1` + `CURRENT_PROJECT_VERSION` to `5`** in
   `ios/project.yml` (manager's top-priority debt repayment — five minutes,
   prevents crash-triage confusion on the next TestFlight upload).
2. **Add IBM Plex Mono / OFL 1.1 attribution to `AboutView.sourceSection`**
   (legal's blocker-if-true; four-line addition with a `Link` to the bundled
   `IBMPlexMono-OFL.txt` or `github.com/IBM/plex`).
3. **Promote `Theme.audit()` into a RELEASE-safe verification path** — a unit
   test that loads the bundled Plex Mono PostScript names and asserts each
   weight resolves, runs as part of pre-archive `xcodebuild test` (greybeard's
   single ship-blocker; mitigates the silent-fallback-to-system-monospaced
   failure mode that the DEBUG-only precondition doesn't catch in archive
   builds).

---

## Key evidence

### Recon (internal)

- 12,256 LOC across 75 Swift sources + 26 test files. Two-target xcodegen split
  (`SkymarshalCore` framework + `Skymarshal` app). Zero SPM dependencies.
  AT Protocol via hand-rolled `URLSession`. SwiftData persistence. Keychain for
  session tokens.
- v1.0.1 restyle (commit `a01876c`): IBM Plex Mono 1.1.0 bundled, `Theme+Fonts.swift`
  + `Theme.audit()`, `SaturnButton` (with explicit v1.0.2 token shim), `ScopePill`,
  nine per-view applications, `TokenCoverageTests`, two new AX5 tests.
- **Gaps flagged:** `Skymarshal.entitlements` is empty (`<dict/>`) despite
  `CLAUDE.md` referencing an app-group container; `project.yml` still pins
  `MARKETING_VERSION 1.0.0 / CURRENT_PROJECT_VERSION 4` while v1.0.1 work has
  shipped.

### Scout (external)

- Closest direct comp: **BskyDelete** ($10/mo or $60/yr, web).
- Free OAuth web competitor surfaced via live web search: **Deletem /
  byesky.app** — matches ~80% of feature parity at $0. Material to monetization
  framing (see Dissenting opinions).
- Aesthetic precedent (Plex Mono / Saturn / Geist Mono operational-console) is
  currently underserved on iOS. Reeder / Things / Soulver prove the
  premium-craft audience exists.
- Biggest external risk: **Bluesky PBC ships first-party bulk-post deletion** in
  2026. They have the API surface, they have the editorial appetite for
  user-data controls.

---

## Risk assessment

1. **Bluesky ships first-party bulk-delete** *(breaker, ranked #1 most damaging
   attack)*. Collapses TAM and makes every other attack worse. **Mitigation:**
   lean harder on the audit + filter + dignified-bot-scoring angle, not on raw
   delete count; treat deletion as table-stakes, treat surface as the moat.
2. **Plex Mono fails to register in RELEASE** *(greybeard, ship-blocker)*. The
   DEBUG-only `Theme.audit()` precondition doesn't catch silent fallback to
   system monospaced face in archive builds. AX5 typography pass ships visibly
   wrong on a non-test device. **Mitigation:** Janitor item #3.
3. **`AboutView` doesn't surface OFL attribution to end user** *(legal,
   blocker-if-true)*. OFL §2's "easily viewable by the user" clause is the App
   Review reading risk. Bundled `IBMPlexMono-OFL.txt` lives in `Resources/Fonts/`
   where iOS users can't reach it. **Mitigation:** Janitor item #2.
4. **Sustained network drop mid-bulk-delete burns 30+ minutes** *(safety)* on
   per-item `URLSession` timeouts with no circuit breaker. **Mitigation
   (v1.0.2):** add a 5-consecutive-failure circuit breaker to
   `ContentService.delete(itemIDs:)` (<2 hour fix).
5. **Plex Mono at AX5 on iPhone SE 3rd gen physically does not fit** the
   kicker + date single-line constraint *(breaker)*. The existing
   `AccessibilityRegressionTests` only run on iPhone 17 in the test plan.
   **Mitigation:** add an iPhone SE destination to the AX5 sweep before public
   release.
6. **`SaturnButton` v1.0.2 token shim never gets removed** *(breaker, manager)*.
   Six months pass, Move #3 doesn't ship, shim becomes the permanent skin.
   **Mitigation:** the `// v1.0.2 shim ↓` comment is the canary; manager calls
   this Deliberate+Prudent today but ages into Deliberate+Reckless past
   ~2 TestFlight cycles.

---

## Kill criteria

- **Ship-blocker (any of):** `Theme.audit()` not promoted to RELEASE-safe
  test → fix and re-archive; OFL attribution missing from `AboutView` → fix and
  re-archive; pre-archive `xcodebuild test` not green → fix.
- **Pivot-trigger (Day 60 post-launch):** fewer than 75 paid conversions in
  the first 60 days, OR more than 60% of TestFlight tester asks reference a
  free tier → flip to cynic's free-core-with-one-time-unlock framing.
- **Sunset-trigger (Day 180):** fewer than $1k ARR, no App Store featuring, and
  Bluesky has shipped (or announced) a first-party bulk-delete feature → wind
  down to MIT-open-source maintenance mode or hand off.

---

## Verification plan

**Hard ship-gates for v1.0.1 → TestFlight (in order of importance):**

1. `xcodebuild test` green on iPhone 17 simulator (196 cases as of `a01876c`;
   should rise to 197+ once janitor item #3 lands).
2. `StyleDiagnosisCapture` visual delta vs the May 14 `docs/screenshots/2026-05-14-roll2/`
   baseline shows no regressions.
3. New unit test for `Theme.verifyFontsRegistered()` (janitor item #3) passes
   against the bundled OTFs in `Resources/Fonts/`.

**Next three tests (~145 min total, tester's ranking):**

1. `DeletionResumabilityTests` — end-to-end XCUITest that interrupts a
   `ContentService.delete(itemIDs:)` mid-batch and asserts the resume path
   honors `DeleteBatchRecovery`. ~90 min. Catches the bulk-delete network-drop
   failure mode safety flagged.
2. `AX5_TypedConfirmSheet` — XCUITest that asserts the `TypedConfirmSheet`
   ≥100-item gate is reachable and operable at AX5 Dynamic Type. ~25 min.
3. `Theme.verifyFontsRegistered` RELEASE-safe smoke — unit test that loads each
   bundled OTF, dumps the PostScript name, and asserts the `Theme.Mono.*`
   resolver picks a real font, not the system fallback. ~30 min. **This is
   janitor item #3.**

**TestFlight beta feedback form** — ask about *observations*, not taste:

- Did you ever see the app sign you out unexpectedly? When?
- Did any deletion stop part-way? Were you told it stopped?
- Any text clipped or cut off? Which screen, what Dynamic Type size?

---

## Architecture fit

v1.0.1 lands inside the existing patterns. `Theme+Fonts.swift` is correctly
placed beside `Theme.swift` in `SkymarshalCore/Standards/`. The DEBUG-only
`Theme.audit()` precondition is the right shape for development; **architect
and safety dissent against greybeard's request to promote it to a
RELEASE-firing precondition** — instead, ship the same logic as a unit-test
verification (janitor item #3).

**Real architectural debt:** `SaturnButton` and `ScopePill` live in
`ios/Skymarshal/UI/Components/` (the app target) while `SkymarshalCore`
already imports SwiftUI for `Theme`. The "no SwiftUI in `SkymarshalCore`" rule
in `AGENTS.md` is mis-stated — the real invariant is *"no SwiftUI **views**
in `SkymarshalCore`"*. Components in the app target block any future Share
Extension / Watch app / iPad-specific surface reuse.

**v1.0.2 follow-up (architect):** ship empty `Theme.paper` / `Theme.hairline`
tokens now, swap the two `// v1.0.2 shim ↓` lines in `SaturnButton`, relocate
both `SaturnButton.swift` and `ScopePill.swift` into a new
`SkymarshalCore/UIComponents/` directory (or a dedicated `SkymarshalUI`
target). Cost: ~2 hours. Unblocks Share Extension / Watch reuse before any
App Group entitlement work begins.

**Concurrency posture:** `@MainActor` `AppModel` + actor services +
`ModelContext`-per-call SwiftData pattern is genuinely safe under iOS 17 strict
concurrency. Two minor traps to flag for the next contributor: redundant
`await MainActor.run` inside a `@MainActor` function, and the load-bearing
no-deinit comment on `observeSessionInvalidation`.

---

## Legal and IP

**Compatible** posture across OFL 1.1, MIT, App Review 5.x, and Bluesky/ATProto.
Subtitle "Cleanup tool for Bluesky." is nominative fair-use with strong
precedent (Graysky, Skeets, Skyscraper). Privacy manifest is correctly
minimal — Keychain is not on Apple's required-reason API list, and
`bsky.social` / `public.api.bsky.app` are not tracking domains. Marketing copy
is clean on the workspace's AI ban-list.

**Watch item:** Bluesky-issued takedown of the subtitle is unlikely but would
trigger 5.2.1; document the nominative-use defense in case it comes up.

**Blocker-if-true:** if Apple reads OFL §2's "easily viewable by the user"
strictly, v1.0.1 falls out of compliance because `IBMPlexMono-OFL.txt` is
unreachable on-device. **Fix:** four-line addition to
`AboutView.sourceSection` — "Typography: IBM Plex Mono · SIL OFL 1.1" with a
`Link` to the bundled OFL.txt or `github.com/IBM/plex`. (Janitor item #2.)

---

## Dissenting opinions

**Cynic (must always dissent — single bullet preserved verbatim):**

> Skymarshal is being priced like a sticky productivity subscription, but it is
> a structurally one-shot utility competing with a $0 OAuth web tool (Deletem
> / byesky.app) — the right framing is free-core iOS with a one-time
> "support the developer" unlock (or MIT open source with a paid hosted-
> convenience tier), not $1.99–$24.99 out of the gate.

**Internal disagreement (preserved, not flattened):**

- **Greybeard vs. architect + safety:** greybeard wants `Theme.audit()` to fire
  in RELEASE as a TestFlight tripwire. Architect and safety dissent — soft
  signal via the existing `Font.system(...monospaced)` fallback is the right
  shape; the verification belongs in `xcodebuild test`, not in production
  `init()`. Resolution: janitor item #3 routes the same intent through a
  unit test.
- **Cynic vs. breaker:** breaker attacks the *tactical* surface (Plex Mono
  width at AX5, dignity rename costing keyword recognition). Cynic attacks
  the *strategic* premise (pricing is anchored to the wrong comp). Both are
  valid; the executive synthesis treats breaker's attacks as ship-time
  mitigations and cynic's attack as a Day-60 pivot trigger.

---

## Consultants consulted

- **Perplexity** (via scout's WebSearch): confirmed BskyDelete pricing comp;
  surfaced **byesky.app / Deletem** as free OAuth web competitors that
  materially reshape cynic's dissent.
- **Gemini, Codex, Grok CLIs:** not invoked this turn.
- **`/consensus` panel:** not invoked this turn; cynic surfaced the strongest
  external counterargument directly.

---

*Synthesized by the executive seat from nine subagent reports (recon, scout,
marketing, legal, manager, architect, greybeard, safety, tester, breaker,
cynic). Editor pass kept light — the council's specifics are the point.
Author: Luke Steuber.*
