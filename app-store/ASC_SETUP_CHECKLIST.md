# App Store Connect setup checklist

Manual steps — cannot be automated from this repo.

## Prerequisites

- Apple Developer Program membership (team `596T7J7FB6` per `project.yml`)
- Bundle ID: `blue.skymarshal.ios` (app), `blue.skymarshal.ios.core` (framework — not submitted separately)

## Steps

1. [ ] [developer.apple.com](https://developer.apple.com) → Identifiers → confirm `blue.skymarshal.ios` exists
2. [ ] App Store Connect → **My Apps** → **+** → New App
   - Platform: iOS
   - Name: Skymarshal
   - Primary language: English (U.S.)
   - Bundle ID: `blue.skymarshal.ios`
   - SKU: `skymarshal-ios` (suggested)
3. [ ] Upload first build via Xcode Organizer or `xcodebuild -exportArchive` after archive
4. [ ] Publish and verify privacy policy URL: `https://skymarshal.blue/privacy` (currently 404)
5. [ ] Support URL: `https://skymarshal.blue/support` (verified 200)
6. [ ] Complete [DEMO_ACCOUNT.md](DEMO_ACCOUNT.md) and paste into App Review Information
7. [ ] Capture screenshots per [SCREENSHOTS.md](SCREENSHOTS.md)
8. [ ] Complete the current age-rating questionnaire and confirm the resulting 4+ rating
9. [ ] Declare supported accessibility features in App Store Connect, including VoiceOver,
   Larger Text, sufficient contrast, and Reduce Motion where Apple's form applies
10. [ ] Run paste session: [APP_STORE_CONNECT_PASTE_SESSION.md](APP_STORE_CONNECT_PASTE_SESSION.md)
11. [ ] Before **Submit for Review**: confirm [docs/SUBMISSION_DECISION.md](../docs/SUBMISSION_DECISION.md) ship-blockers

## TestFlight (public link) — before or instead of App Store

See [docs/TESTFLIGHT_PUBLIC_LINK.md](../docs/TESTFLIGHT_PUBLIC_LINK.md).
