# Skymarshal iOS App Store Connect Paste Session

Last updated: 2026-05-12 (reconciled)

Use this checklist in one uninterrupted session while filling App Store Connect.

## Session Setup (2 minutes)

- Open App Store Connect -> My Apps -> `Skymarshal`
- Open your target version record (for example, `1.0.0`)
- Keep these files open side-by-side:
  - `PUBLIC_RELEASE_COPY.md`
  - `PUBLIC_RELEASE_ASSETS.md`
  - `SUBMISSION_NOTES.md`

## Step 1: App Information

Paste/confirm:

- Name: `Skymarshal`
- Subtitle: `Cleanup tool for Bluesky.`
- Category:
  - Primary: `Social Networking`
  - Secondary: `Utilities`
- Content Rights: mark truthfully based on current app behavior

## Step 2: Pricing and Availability

- Price: `Free`
- Territories: `All` (or your launch list)

## Step 3: App Privacy

- Data collection: `Data Not Collected` across all categories
- Tracking: `No`

Confirm policy language matches:

- No analytics
- No third-party SDK tracking
- No Skymarshal-hosted user-data backend

## Step 4: Version Information

Paste these fields:

- Promotional Text:
  `Search every post, reply, repost, and like in your archive — tidy in bulk. Score your follow list for bots and inactive accounts. App password only, nothing tracked.`
- Description:
  Use the full Description block from `PUBLIC_RELEASE_COPY.md`.
- Keywords:
  `posts,replies,reposts,likes,archive,manage,delete,follower,unfollow,bot,atproto,bulk,clean,filter`
- What's New in This Version:
  Use the `What's New (v1.0.0)` block from `PUBLIC_RELEASE_COPY.md`.

## Step 5: App Review Information

Paste:

- Contact email: `skymarshal@lukesteuber.com`
- Contact phone: your reviewer-reachable number
- Demo account: leave blank unless requested
- Notes for Review:
  Use the full `App Review Information` block from `SUBMISSION_NOTES.md`.

## Step 6: URLs

Paste:

- Marketing URL: `https://skymarshal.blue`
- Support URL: `https://skymarshal.blue/support`
- Privacy Policy URL: `https://skymarshal.blue/privacy`

Open each URL in a browser and confirm it resolves publicly before submission.

## Step 7: Build and Binary

- Attach processed build for this version
- Confirm build number matches release plan
- Confirm export compliance answers match `Info.plist` and current app behavior

## Step 8: Screenshots and App Icon

Upload/verify:

- iPhone 6.9-inch screenshot set
- iPhone 6.1-inch screenshot set
- App icon 1024 x 1024

Run final visual QA:

- No placeholder content
- No typos
- No references to unshipped features
- Brand voice matches listing text

## Step 9: Final Pre-Submit Gate

Check all:

- [ ] Metadata saved without validation errors
- [ ] Privacy section complete
- [ ] URLs reachable
- [ ] Build attached and selectable
- [ ] Screenshot sets complete for required iPhone sizes
- [ ] Review notes pasted

Then submit for review.

## 10-Minute Rejection Prevention Pass

Before pressing submit, scan for these known tripwires:

- Trademark ambiguity: ensure non-affiliation language is present
- App-password confusion: review note explains Bluesky app passwords
- Destructive actions: screenshots and description mention confirmation safety
- Privacy mismatch: listing claims must match App Privacy answers
