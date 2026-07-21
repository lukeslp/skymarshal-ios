# Skymarshal — App Store media

Current media source: [Skymarshal — App Store Media](https://www.figma.com/design/iRvznhAE3wvd9UPGcB7U0X).
The board contains the editable, real-capture iPhone and iPad sets plus the
complete App Store Connect copy. It is the review surface; the native app is
the capture source.

## Release set

The current staged set is the same six-frame sequence for both device classes:

| # | iPhone 6.9" | iPad 13" | Story |
| --- | --- | --- | --- |
| 1 | `01-welcome` | `01-welcome` | Sign in with an app password — the main password stays yours. |
| 2 | `01-search` | `01-search` | Search an entire archive: posts, replies, reposts, and likes. |
| 3 | `02-filters` | `02-filters` | Filter in layers: media, alt text, date, and engagement. |
| 4 | `03-media-results` | `03-media-results` | Surface posts worth revisiting — see the media before acting. |
| 5 | `04-followers` | `05-content` | Read the follow list at a glance / work through the full archive on iPad. |
| 6 | `05-account-detail` | `06-account-detail` | Inspect the signals and account context before a bulk action. |

The first four frames establish safe access, archive search, precision filters,
and reviewable results. The final two make the follower-analysis and
human-review safeguards tangible. Do not add a generic app-icon frame: every
slot should explain a distinct capability.

### Widget media gap

Version 1.0.2 also includes five network-free widgets, but the checked-in media
set does not yet show them. Before final submission, add one authentic seventh
frame per device class using a real Home Screen composition with Worth Joining,
Your Top Post, and Follower Trend populated from the same demo scan. Keep the app
visible in the background or adjacent device frame so the relationship is clear;
do not fabricate widget chrome in the renderer. The six current frames are safe
to stage now and remain the fallback if the real widget capture is not ready.

## Capture and upload

```sh
cd ios
bundle exec fastlane screenshots
SKY_EXPECTED_SHOTS=6 bundle exec fastlane upload_screenshots
```

`screenshots` requires a previously signed-in simulator or the documented demo
credentials in `app-store/DEMO_ACCOUNT.env`. Never put credentials in source.

`upload_screenshots` stages from `ios/screenshots-appstore/`, requires matching
iPhone and iPad counts, and rejects sets captured more than 24 hours apart. It
also flattens an occasional transparent iPad attachment to white before
uploading, since App Store screenshots must be opaque. If ImageMagick is not
available, install it with `brew install imagemagick` before staging a capture
that has transparency.

## Preflight

- Six opaque PNGs in each class now; seven after the authentic widget frame lands.
- iPhone 6.9": `1320 × 2868`.
- iPad 13": `2064 × 2752`.
- Use the pinned 9:41 / full-battery status bar from the capture script.
- Review the Figma board for story order and copy before uploading.
- Upload screens and listing separately; neither lane uploads a binary or
  submits a version for review.
