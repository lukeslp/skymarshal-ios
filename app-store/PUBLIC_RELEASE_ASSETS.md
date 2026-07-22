# Skymarshal iOS public release assets

## App icon

- `1024 × 1024` PNG, RGB, no alpha.
- Source: `ios/Skymarshal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- The current mark is a simple flat bird-and-radar design.

## Required screenshot sets

Skymarshal is a universal iPhone and iPad app. Use the highest-resolution set
for each platform:

- iPhone 6.9-inch: five `1320 × 2868` PNGs.
- iPad 13-inch: five `2064 × 2752` PNGs.
- App Store Connect accepts one to ten screenshots per device class and scales
  the iPhone set for smaller displays.

The canonical sequence and captions live in `SCREENSHOTS.md`. Staged files live
in `ios/fastlane/screenshots/en-US/`.

## Optional later assets

- App Preview video, after the static listing is stable.
- Custom Product Page variants, after baseline conversion data exists.
- In-App Event art, when there is an actual time-bound event.

## QA gate

- [ ] Exact dimensions and opaque RGB color.
- [ ] No placeholder, private, inflammatory, or age-inappropriate content.
- [ ] Every caption matches what is visible.
- [ ] No simulator chrome or clipped status bars.
- [ ] App icon matches the binary.
- [ ] Listing includes the non-affiliation disclosure.
