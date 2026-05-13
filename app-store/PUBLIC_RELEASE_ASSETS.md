# Skymarshal iOS Public Release Asset Checklist

Last updated: 2026-05-12

This checklist covers visual assets required to ship publicly on iOS.

## Required Assets (iOS)

### App Icon

- Size: 1024 x 1024 px
- Format: PNG
- Color space: sRGB or Display P3
- Transparency: none
- Location in repo:
  - `ios/Skymarshal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`

### iPhone Screenshots

For new submissions, provide both required sets:

- 6.9-inch display screenshots
- 6.1-inch display screenshots
- Count: up to 10 per size (7 recommended for current storyboard)
- Format: PNG or JPEG, RGB color space

Storyboard source:

- `SCREENSHOTS.md`

## Optional Assets (Recommended Later)

- iPad screenshots (only if promoting iPad use explicitly)
- App Preview video (adds review surface area; skip for initial release)
- In-App Event card art (after launch cadence is stable)
- Custom Product Page screenshot variants (after baseline conversion data)

## Frame-Level Narrative Sequence

Use this message order in screenshot captions:

1. Search everything
2. Filter precisely
3. Clean followers
4. Select at scale
5. Confirm destructive actions
6. Inspect account signals
7. Privacy posture

## Export and Validation

- Verify dimensions before upload:
  - `sips -g pixelWidth -g pixelHeight <file>`
- Ensure no simulator chrome overlays
- Keep readable text away from status bar and bottom safe area
- Confirm consistency across light/dark mode in the chosen sequence

## QA Gate Before Upload

- [ ] No placeholder data in screenshots
- [ ] No typo in captions
- [ ] No competitor names in overlays
- [ ] "Not affiliated with Bluesky Social, PBC" appears in listing text
- [ ] Login screenshot shows app-password language
