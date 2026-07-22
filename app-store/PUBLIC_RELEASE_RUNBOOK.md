# Skymarshal iOS Public Release Runbook

Last updated: 2026-05-12

This runbook is the operational checklist for submitting and launching the public release.

## T-7 to T-3 Days: Freeze and Verify

- [ ] Confirm release build number and version string
- [ ] Run full test suite in CI/local
- [ ] Execute large-account soak checklist: [`docs/SOAK_PROTOCOL.md`](../docs/SOAK_PROTOCOL.md) (screen recording + device)
- [ ] Validate login, search, bulk delete, bulk unfollow on real device
- [ ] Reconfirm privacy posture and URLs
- [ ] Finalize App Store copy from `PUBLIC_RELEASE_COPY.md`
- [ ] Finalize screenshots from `SCREENSHOTS.md`

## T-2 to T-1 Days: App Store Connect Prep

- [ ] Create/update app version record
- [ ] Paste metadata fields
- [ ] Upload screenshots (6.9-inch iPhone and 13-inch iPad sets)
- [ ] Upload/select app icon
- [ ] Set categories and age rating
- [ ] Confirm App Privacy is Data Not Collected
- [ ] Paste App Review Information note
- [ ] Verify marketing/support/privacy URLs resolve publicly

## Submission Day

- [ ] Archive release build in Xcode
- [ ] Upload via Organizer or Transporter
- [ ] Wait for processing completion
- [ ] Attach build to release version
- [ ] Submit for review
- [ ] Record submission time and version in internal changelog

## While In Review

- [ ] Monitor Resolution Center every few hours
- [ ] Keep reviewer-response template ready
- [ ] If requested, provide reviewer test account details quickly
- [ ] Prepare social/website/email copy for immediate publish

## Launch Day

- [ ] Confirm app status is Ready for Sale
- [ ] Publish website update at `skymarshal.blue`
- [ ] Publish launch social post
- [ ] Send newsletter/email announcement
- [ ] Post support article with onboarding + app-password setup

## +24h and +72h Post-Launch

- [ ] Review crashes and critical support tickets
- [ ] Capture App Store ranking + conversion baseline
- [ ] Triage first wave of reviews and respond
- [ ] Log copy/screenshot optimization hypotheses for v1.0.1

## Reviewer Response Templates

### Trademark/affiliation clarification

Skymarshal is an independent third-party utility and is not affiliated with Bluesky Social, PBC. "Bluesky" is used descriptively to indicate network compatibility.

### Data collection clarification

Skymarshal does not collect, store, or track user data. Authentication uses Bluesky app passwords, and network calls are made directly from device to Bluesky endpoints.

### Destructive actions clarification

All destructive actions include confirmation safeguards and rate-limit-aware retries to reduce accidental or unsafe bulk operations.
