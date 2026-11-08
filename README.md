# Skymarshal iOS

The replacement iOS app uses the shared content manager from [skymarshal-web](https://github.com/lukeslp/skymarshal-web), bundled locally through Capacitor. Its canonical XcodeGen project is `ios/App/project.yml` in that repository. Web and iOS use the same management screens and execution engine.

This repository preserves the earlier SwiftUI app and its release history. New content-manager work belongs in `skymarshal-web`; do not submit an old SwiftUI build as the replacement.

## Replacement

The candidate keeps bundle ID `blue.skymarshal.ios`, the existing icon and signing team, and iPhone/iPad support from iOS 17. It provides inventory, filtering, frozen scope review, exports, durable jobs and verified receipts. Bluedrop remains a separate messenger.

Authentication uses the official OAuth client with a narrow native system-browser bridge. Explicit app-password fallback and saved accounts use a new Keychain namespace. Old native Keychain and SwiftData data are preserved without importing old cleanup operations.

Build commands, platform boundaries, measured checks and remaining release gates are in [the replacement handoff](https://github.com/lukeslp/skymarshal-web/blob/main/docs/IOS_CONTENT_MANAGER.md).

## Release state observed November 8, 2026

App Store Connect serves **1.1.0 (52)**. Uploaded build **53** is not the public build. The shared-manager candidate is **2.0.0 (54)** and has not been submitted to Apple. Historical documentation below `docs/` and `app-store/` describes the earlier native implementation; it does not qualify the replacement.

The legacy source remains buildable from `ios/project.yml` for diagnosis and recovery. Use XcodeGen rather than editing its generated project. Its tests do not replace the shared manager's browser and native qualification gates.

## License

MIT — © 2026 Luke Steuber.
