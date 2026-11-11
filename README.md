# Skymarshal for iOS (retired native app)

[![Status: end of life](https://img.shields.io/badge/status-end_of_life-lightgrey?style=flat-square)](#skymarshal-for-ios-retired-native-app)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

**Status: end of life.** I have stopped developing this app. It gets no further
features, fixes or support from me. The code stays here under the MIT license
as a record, and for anyone who wants to read or reuse it.

This repository holds the native SwiftUI version of Skymarshal, a Bluesky
content manager for iPhone and iPad. Its last public release is 1.1.0
(build 52), which reached the App Store on August 10, 2026. Build 53 was
uploaded to TestFlight on September 4, 2026 and was never released publicly.

## What replaced it

Skymarshal continues as a shared content manager. It runs on the web at
https://skymarshal.blue and ships as the iOS app from version 2.0.0, under the
same bundle ID, `blue.skymarshal.ios`. As of November 10, 2026, version 2.0.0
is in TestFlight and waiting for App Store review, and the App Store still
serves 1.1.0 from this code.

That work happens in a separate repository. A build from this repository is not
the replacement and should not be submitted as one. The replacement leaves this
app's Keychain and SwiftData data in place and does not import its pending
cleanup operations.

## What this app did

- **Content:** posts, replies, likes and reposts, with search, filters, saved
  searches, sorting, media and alt text review, on-device insights, and CSV or
  JSON export.
- **Patterns:** a review of the accounts you follow, with activity signals,
  an allowlist, presets, interaction history and unfollow actions.
- **Scope:** local graphs of your account and posts, interaction summaries and
  a heatmap.
- **Cleanup safety:** a preflight count, typed confirmation for large batches,
  resumable deletion, pacing, cancellation, and a stop after repeated failures.
- **Widgets:** five Home Screen widgets that read snapshots written by the app.

It signs in with a Bluesky app password, keeps the session in the Keychain, and
talks to Bluesky directly through its own AT Protocol client built on
`URLSession`. It has no third-party AT Protocol SDK.

## Building it

The app targets iOS 17 and later on iPhone and iPad. The project is defined in
`ios/project.yml` for XcodeGen, with the scheme `Skymarshal`. Change settings
in the YAML, not in the generated Xcode project.

The source was last built for release in September 2026, for build 53. I have
not rebuilt it since.

## The documents here

Everything under `docs/` and `app-store/` describes this app as it was. Those
documents are kept as written and are not maintained. Each one carries a short
note saying so.

`reference/` holds Python and TypeScript material copied from earlier
Skymarshal tools on May 9, 2026. [MIGRATION.md](MIGRATION.md) records where it
came from.

## License

MIT. © 2026 Luke Steuber.
