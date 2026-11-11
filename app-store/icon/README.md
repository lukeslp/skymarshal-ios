# Icon + header source

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../../README.md).

`AppIcon.svg` is the canonical source for the app icon. The asset catalog
(`ios/Skymarshal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`) is
rendered from it — edit the SVG, then run `./render.sh` to regenerate the PNG.

`ScopeHeader.svg` is the source for the launch-screen / login header image
(`ios/Skymarshal/Assets.xcassets/ScopeHeader.imageset/`, @1x/@2x/@3x). It is
the dot-matrix Blackbird that replaced the `EasterAlf` (ALF) art on build 27.
Re-render the three scales with headless Chrome the same way `render.sh` does
(1024×576, 2048×1152, 3072×1728), flattening to opaque sRGB.

## Design

"Blackbird" — a stealth-delta planform that reads as both an SR-71 silhouette
and swept wings, centered on a dot-matrix radar scope with an orange lock-on.
Keeps the brand DNA (air-traffic-control scope + bird + dot-matrix + sky/orange)
while being unmistakably a bird/aircraft — no creature face.

Introduced for build 27 (2026-06-18), replacing the dot-matrix bird-face icon
that read as a copyrighted character (ALF) and risked an App Store 4.1
copycat objection.

## Rendering

`render.sh` uses headless Chrome because ImageMagick's builtin SVG renderer
drops gradients. Output is flattened to opaque sRGB with no alpha channel
(Apple rejects icons that contain alpha).
