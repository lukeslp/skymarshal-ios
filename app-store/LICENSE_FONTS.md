# Font licenses

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

Skymarshal bundles the following open-source typefaces under the SIL Open Font
License 1.1. The full license text ships inside the app bundle alongside each
typeface (see `ios/Skymarshal/Resources/Fonts/`).

## IBM Plex Mono — added in v1.0.1 (build 5)

Copyright © 2017 IBM Corp. with Reserved Font Name "Plex".

Distributed under the SIL Open Font License 1.1 — https://scripts.sil.org/OFL.

- Upstream: https://github.com/IBM/plex
- Release: `@ibm/plex-mono@1.1.0`
- Variants shipped: Regular (400), Medium (500), SemiBold (600).
- PostScript names used at runtime: `IBMPlexMono`, `IBMPlexMono-Medm`,
  `IBMPlexMono-SmBld`. Plex 6.0 (Sep 2021) abbreviated the Medium / SemiBold
  PostScript names; the `Theme.audit()` DEBUG precondition in
  [`Theme+Fonts.swift`](../ios/SkymarshalCore/Standards/Theme+Fonts.swift)
  accepts either spelling so a future Plex re-release that restores the long
  names won't silently break the build.

OFL.txt for the bundle is at `ios/Skymarshal/Resources/Fonts/IBMPlexMono-OFL.txt`.
