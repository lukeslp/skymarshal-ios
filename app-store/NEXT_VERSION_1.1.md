# Next App Store version — 1.1

## Where things stand (2026-06-22)

- **v1.0.1 (build 27, native SwiftUI) is `WAITING_FOR_REVIEW`** in ASC (app id
  `6768003674`). It is fully submitted — copy + 11 screenshots are in ASC and
  **locked while in review**. Nothing more to push for 1.0.1; wait for Apple's verdict.
- The ASC version string was `1.0`; it was aligned to **`1.0.1`** to match build
  27's marketing version (they were mismatched). Review was not reset.
- Committed screenshot set in the repo: `ios/screenshots-appstore/`
  — `iphone-6.9` (6), `ipad-13` (6), `iphone-6.1` (2). These are the **native UI**.

## Plan: ship 1.0.1, then 1.1

- **1.0.1 APPROVED + released** → create version **1.1** in ASC. (You can't create a
  new version while 1.0.1 is in review — Apple blocks it; spaceship `ensure_version!`
  will *rename* the in-review version instead, which is how it briefly became 1.0.1.)
- **1.0.1 REJECTED** → fix *this* version and resubmit; don't create 1.1 yet.

## 1.1 = the Option B Capacitor rebuild

1.1 is intended to be the **Capacitor web-wrapper** (the pivot) — repo
`~/workspace/skymarshal-web`, branch `feature/ios-capacitor-wrapper`, plan in
`CAPACITOR_WRAPPER.md`. Same bundle id `blue.skymarshal.ios` (same listing).

Pre-reqs before 1.1 can ship:
- Finish the Option B open items: native delete-plugin **registration** (use a local
  Swift Package or set an explicit non-generic `PRODUCT_MODULE_NAME` — the storyboard
  custom-VC route blanks the WebView), `VITE_API_URL` wiring, production signing +
  app icon, archive the `App` scheme.
- **Recapture screenshots of the Capacitor UI** — 1.1 ships the web look, so the
  current committed native shots won't match (keep them as a fallback only if 1.1
  ends up shipping native).

## Upload steps (once the 1.1 version exists in ASC)

```bash
cd ios && source ~/.appstoreconnect/env.sh
# bump version/build in project.yml (native) or the Capacitor build first
fastlane upload_listing        # metadata only, no submit
fastlane screenshots           # capture (SKY_TEST_* from app-store/DEMO_ACCOUNT.env)
fastlane upload_screenshots    # no submit; needs both device classes equal, or SKY_ALLOW_PARTIAL=1
# attach the 1.1 build in ASC, add a real "What's New", then Submit manually
```

## Known capture gotcha

The XCUITest `screenshots` lane **fails on iPad at the Followers tab**
("Followers tab not reachable" — iPad's tab layout differs from iPhone's, so the
`app.tabBars.buttons["Followers"]` / `app.buttons["Followers"]` lookups miss).
Fix the iPad Followers navigation in `SkymarshalUITests/ScreenshotTest.swift`
before relying on `fastlane screenshots` for the iPad set.
