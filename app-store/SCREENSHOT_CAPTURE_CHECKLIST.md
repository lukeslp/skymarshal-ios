# Screenshot capture checklist

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**Target:** 10 PNGs: 5 frames for iPhone 6.9-inch and 5 for iPad 13-inch, per [SCREENSHOTS.md](SCREENSHOTS.md).

## Simulator setup

```bash
cd ios
xcodegen generate --spec project.yml
xcrun simctl boot "iPhone 17"   # 6.9" class — adjust per SCREENSHOTS.md device names
```

Launch with UITest bootstrap or signed-in test account so lists are populated.

## Frames

1. Archive search
2. Advanced filters
3. Media results
4. Patterns scan summary
5. Scope graphs and stats

Repeat on the iPad 13-inch simulator.

## Output

Save raw app captures under `ios/screenshots-appstore/`:

```
ios/screenshots-appstore/
  iphone-6.9/
    01-search.png
    ...
  ipad-13/
    01-login.png
    ...
```

## Automation (optional later)

Consider `SkymarshalUITests` snapshot lane per generators/screenshot-automation skill — not required for this tranche if manual capture completes in ~30 min.

## Checklist

- [ ] 5 × iPhone 6.9-inch PNGs
- [ ] 5 × iPad 13-inch PNGs
- [ ] No personal tokens visible in shots
- [ ] Dark mode set consistently (or both if marketing wants)
