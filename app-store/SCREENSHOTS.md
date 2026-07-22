# Skymarshal App Store screenshots

The checked-in release set contains five screenshots for iPhone 6.9-inch and
iPad 13-inch. These are the same images staged under
`ios/fastlane/screenshots/en-US/` and shown on the live listing.

## Release sequence

| # | Source view | Caption |
| --- | --- | --- |
| 1 | Archive search | Search and manage content in bulk |
| 2 | Advanced filters | Filter by keyword, date, or engagement |
| 3 | Media results | Review posts, replies, likes, and media |
| 4 | Patterns | Review the accounts you follow |
| 5 | Scope | Explore graphs, activity, and stats |

All frames render from authentic app captures in `ios/screenshots-appstore/`.
The prior widget frame included unsuitable public post text and was removed.
Add widgets back only after capturing neutral demo content from the real widget.
Do not fabricate widget chrome or post content.

## Render and stage

```sh
cd ios
swift scripts/render_marketing_screenshots.swift
cp screenshots-marketing/iphone-6.9/*.png fastlane/screenshots/en-US/
cp screenshots-marketing/ipad-13/*.png fastlane/screenshots/en-US/
```

The Fastlane files use device prefixes (`iphone69-` and `ipad13-`), so stage
with the existing names or the upload lane rather than the literal `cp`
commands when preparing a submission.

```sh
cd ios
SKY_EXPECTED_SHOTS=5 bundle exec fastlane upload_screenshots
```

The upload lane checks matching counts, capture age, dimensions, and alpha.
It uploads screenshots only; it does not upload a binary or submit a version.

## Preflight

- Five opaque PNGs per device class; App Store Connect accepts up to ten.
- iPhone 6.9-inch: `1320 × 2868`.
- iPad 13-inch: `2064 × 2752`.
- Captions must describe the visible screen, not a later action.
- Use demo content suitable for a 4+ product page.
- Check every image at thumbnail size and full size before upload.
