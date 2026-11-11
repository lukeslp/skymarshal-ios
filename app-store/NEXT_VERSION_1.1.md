# App Store release state — 1.1 submitted

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

> **2026-08-05:** **1.1.0 / build 52 is submitted** and `WAITING_FOR_REVIEW`, build
> attached, manual release after approval. **1.0.3 is the live version.**
>
> 1.1 shipped as the **native SwiftUI app**. The June plan in which "1.1 = the Option B
> Capacitor rebuild" was **not taken**; that framing is dead, not deferred. The Capacitor
> prototype remains a proposed alternative only — see `CLAUDE.md`.

## Verify state before trusting any of this

Version claims in this repo have been wrong twice. `CLAUDE.md` and `PROJECT_PLAN.md` both
said 1.0.2 / build 40 was live while ASC said 1.0.3. Git cannot tell you what shipped —
only what was committed.

```bash
cd ios && fastlane asc_state    # read-only: live version, edit version, build states
```

## What 1.1 contains

Versus the live 1.0.3, the only user-visible changes are:

- **Ghost likes** — likes whose subject author was deleted or suspended. Invisible to
  `getActorLikes`, so previously undeletable. Now reconciled from
  `com.atproto.repo.listRecords` and deletable through the normal path.
- **Word patterns** in Insights, on by default.
- Removal of a settings toggle that controlled nothing.

The release notes also re-list Guided Mode, the VoiceOver pass, rate-limit copy, and the
icon. Those shipped in 1.0.3 — the notes were drafted against a wrong baseline and
over-claim. Harmless for review (Guideline 2.3.12 penalizes under-describing) but worth
correcting in 1.2's notes.

## Release lanes

```bash
cd ios
fastlane release_testflight    # xcodegen + archive + upload to TestFlight
fastlane testflight_notes      # wait for processing, attach what_to_test.txt, distribute
fastlane upload_listing        # App Store metadata only, no submit
fastlane submit_for_review     # align ASC version to project.yml, attach build, submit
fastlane asc_state             # read-only state check
```

Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `ios/project.yml` first — ASC
rejects a reused build number, and a build cannot attach to a version whose string
differs from `CFBundleShortVersionString`.

## Live gotchas

- **The ASC version record and the binary must agree.** On 2026-08-05 a `1.0.4` version
  was open while the binary said `1.1.0`; the build would not attach until `deliver`
  renamed the record. Renaming works in `PREPARE_FOR_SUBMISSION` — ASC blocks it once the
  version is in review.
- **`~/.appstoreconnect/env.sh` is stale** — it exports a rotated-out key id whose `.p8`
  was deleted. The lanes read `api_key.json` instead and are unaffected, but anything
  sourcing `env.sh` by hand will fail to authenticate.
- **Run fastlane under a UTF-8 locale.** `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`. Without
  it a single em dash in the notes fails with `invalid byte sequence in US-ASCII`, and it
  fails *after* the build is located, so it reads like an ASC fault.
- **The XCUITest `screenshots` lane fails on iPad at the Patterns tab**
  ("Patterns tab not reachable" — iPad's tab layout differs from iPhone's, so the
  `app.tabBars.buttons["Followers"]` / `app.buttons["Followers"]` lookups miss). Fix the
  iPad Followers navigation in `SkymarshalUITests/ScreenshotTest.swift` before relying on
  `fastlane screenshots` for the iPad set.
- **Committed screenshots are the native UI** at `ios/screenshots-appstore/` —
  `iphone-6.9` (6), `ipad-13` (6), `iphone-6.1` (2).

## Open for 1.2

- **Ghost likes has never run against real data.** It shipped on synthetic-test
  confidence. A decode failure degrades silently to "no ghosts", which is
  indistinguishable from an account that has none — so absence is not evidence it works.
- Correct the release notes baseline (see above).
- Timeframe quick-filter chips (7d/30d/90d/1y) — the last open parity item.
