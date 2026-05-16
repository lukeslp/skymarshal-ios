# Screenshot capture checklist

**Target:** 14 PNGs — 7 frames × 6.9" + 7 frames × 6.1" per [SCREENSHOTS.md](SCREENSHOTS.md).

## Simulator setup

```bash
cd ios
xcodegen generate --spec project.yml
xcrun simctl boot "iPhone 17"   # 6.9" class — adjust per SCREENSHOTS.md device names
```

Launch with UITest bootstrap or signed-in test account so lists are populated.

## Frames (suggested order)

1. Login / scope header (dot-matrix)
2. Content list with filters visible
3. Search / filter chips active
4. Delete confirmation (small batch — no real deletes)
5. Followers scan summary
6. Insights sheet (if enabled for shots: `-sm.feature.wordPatterns YES` optional)
7. About / trust copy (app password language)

Repeat on second simulator size (6.1").

## Output

Save under `app-store/screenshots/` (create directory; add to git if size allows, or store in asset pipeline only):

```
app-store/screenshots/
  6.9/
    01-login.png
    ...
  6.1/
    01-login.png
    ...
```

## Automation (optional later)

Consider `SkymarshalUITests` snapshot lane per generators/screenshot-automation skill — not required for this tranche if manual capture completes in ~30 min.

## Checklist

- [ ] 7 × 6.9" PNGs
- [ ] 7 × 6.1" PNGs
- [ ] No personal tokens visible in shots
- [ ] Dark mode set consistently (or both if marketing wants)
