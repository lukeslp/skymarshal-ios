# Skymarshal — App Review submission notes

Pre-submission checklist + the App Review Information block to paste
into App Store Connect.

---

## App Review Information (paste verbatim into App Store Connect)

```
Skymarshal is a third-party Bluesky archive-management utility. It is
not affiliated with Bluesky Social, PBC, and is not a Bluesky client —
you cannot post or browse the timeline from Skymarshal. The app reads
the user's own content via the public AT Protocol XRPC endpoints
(bsky.social and public.api.bsky.app), scores it locally, and lets the
user delete their own posts/replies/reposts/likes or unfollow accounts
they currently follow.

There is no server we operate. There is no account on our end. There is
no analytics or tracking. The user signs in with a Bluesky-issued app
password (a separate disposable credential, generated at
bsky.app/settings/app-passwords); their primary password never enters
our app or our infrastructure.

To test:
  1. Create or use an existing Bluesky account at bsky.app
  2. Generate an app password under Settings → App Passwords
  3. Launch Skymarshal, enter handle (e.g. yourname.bsky.social) and
     the app password
  4. The Content tab paginates through the user's own posts, replies,
     reposts, and likes; filter by content type, date, engagement, or
     keyword/alt-text
  5. The Followers tab scans the user's follow list and scores each
     account; sort, filter, or bulk-unfollow as desired
  6. Sign out via the account menu (top-left); session token is cleared
     from Keychain

Demo account is not provided because the product's value is operating
on the user's own archive — a populated demo account would be testing
artifacts, not the product. If reviewer would like a demo account
nonetheless, we will create one and supply credentials within 24 hours
of request.

Contact for App Review questions: skymarshal@lukesteuber.com
```

---

## Pre-submission self-audit (top guideline risks for this category)

Run through these BEFORE you tap "Submit for Review." Each is a real
rejection trigger we've matched against current App Review behavior.

### 5.1.1 — Privacy / data collection

- [x] Privacy nutrition label declares "Data Not Collected" for every
      category. Verify in App Store Connect → App Privacy.
- [x] No third-party SDKs (verify: no Swift Packages, no CocoaPods,
      no Carthage; only Apple frameworks)
- [x] PrivacyInfo.xcprivacy ships in the app target with
      NSPrivacyTracking = false and accessed-API CA92.1 (UserDefaults
      reason) declared
- [x] Privacy Policy URL is reachable and matches the in-app posture
      (one-page "we collect nothing" policy is fine; reviewer just
      needs the URL to load)
- [x] Optional JSON backup import: in-app copy and gatekeeper require a
      signed-in session and **reject** handle/DID mismatches (see
      `ContentBackupImport`); aligns with 5.1.2 reviewer narrative
- [x] Optional on-device experiment counters (UserDefaults) for Scope
      navigation testing — **not** declared as collected data; no
      transmission off-device
- [x] App password storage uses Keychain, not UserDefaults; Keychain
      access is documented in the privacy policy

### 5.2.1 — Trademarks / IP

- [x] Product name is "Skymarshal" — not "Bluesky" or anything that
      could be mistaken for Bluesky's own product
- [x] No use of Bluesky's butterfly logo or icon set; the app icon is
      original (scope-rings on Bluesky-blue gradient — descriptive
      use of color, not logo)
- [x] Description discloses "Not affiliated with Bluesky Social, PBC"
      explicitly
- [x] "Bluesky" appears in subtitle / description as descriptive
      reference to the network the app operates on, never as
      possessive ("Bluesky's archive cleaner") or claiming
      endorsement
- [x] Marketing URL points to skymarshal.blue (which we own), not a
      Bluesky-namespace squat

### 4.1 — Copycats

- [x] App is functionally distinct from Bluesky's own app — different
      purpose (archive management vs. timeline browsing), different
      core flow (search + delete vs. compose + read), different
      visual identity (scope motif vs. butterfly)
- [x] Description leads with what the app does that Bluesky's own
      app doesn't (bulk operations, cross-archive search,
      bot scoring)
- [x] Established category precedent on iOS: Graysky (October 2023,
      established third-party Bluesky client), Skeets (native SwiftUI),
      and Skyscraper (January 2026 launch) have all received App Store
      approval as third-party Bluesky clients. Skymarshal differs in
      scope — cleanup-focused rather than reading-focused — and is the
      first native iOS entry in the cleanup-tool category (web-only
      competitors: BskyDelete, Redact, Skeet Deleter, Bluesky Repo
      Explorer)

### 4.2 — Minimum functionality

- [x] Native SwiftUI implementation (not a WKWebView wrapper)
- [x] Substantive features beyond a single API call: filter sheet,
      multi-axis search, bot scoring engine, cursor pagination,
      bulk operations with rate-limit handling
- [x] Multiple screens with distinct functionality (Login, Content,
      Followers, FilterSheet, EditActionBar)
- [x] Native iOS surfaces respected: search bar, EditMode, swipe
      actions, confirmation dialogs, segmented controls

### 1.1.6 — User-generated content

- [x] App displays only the signed-in user's OWN content (their
      own posts, their own follow list)
- [x] No public discovery surface, no comments section, no method
      for users to submit content INTO the app
- [x] Bulk delete is irreversible by design and the user is
      explicitly warned before any destructive action

### 4.0 — Design / 4.5.4 — Push notifications

- [x] No push notifications in v1 (skip the entitlement entirely)
- [x] Confirmation dialogs precede every destructive action
- [x] Loading states + error messages visible (ScanInFlightView,
      ScanErrorBanner, LoadProgressBanner)
- [x] EditMode + selection + bulk action discoverable without prior
      training

### 2.1 — App completeness

- [x] No placeholder content shipped (no "Lorem Ipsum", no TODO
      strings, no test handles in copy)
- [x] No commented-out features advertised in description
- [x] App boots clean on first launch in a fresh simulator (no
      crash before login)

### 3.1.1 — In-App Purchase

- [x] No IAP in v1. ITSAppUsesNonExemptEncryption = false in
      Info.plist (confirmed)
- [x] If subscription model added later, never gate core
      functionality behind IAP without a free baseline
- [x] No external payment links, no donation prompts, no
      crypto/web3 features

### 5.1.5 — Location / 5.1.7 — Bluetooth / 5.1.8 — etc.

- [x] No location permission requested
- [x] No bluetooth, camera, microphone, photos, contacts,
      calendars, reminders, or health permissions requested

---

## Things that COULD trip review (not auto-blockers, but watch)

1. **App password concept may confuse reviewer.** First-time-on-Bluesky
   reviewers might not know what an app password is. The login screen
   explains + links to bsky.app/settings — this is enough, but if
   reviewer asks for clarification, point them at the App Review
   Information note above.

2. **Bulk delete is scary in screenshot review.** A reviewer sees
   "Delete 47 items" and may flag for safety. The submission notes
   call out the multi-step confirmation explicitly. Frame 5 of the
   screenshot storyboard exists specifically to preempt this.

3. **"Not affiliated with Bluesky" disclaimer should be visible
   somewhere a reviewer skims.** It's in the description's
   "WHAT IT'S NOT" section. Belt-and-suspenders: also include in
   the Marketing URL landing page.

4. **5.2.1 if Bluesky ever issues a takedown.** Unlikely given the
   app is descriptive use, but if Bluesky's legal ever pings, have
   the response ready: "Skymarshal is descriptive use of the network
   name as a third-party utility, comparable to TweetDeck for Twitter
   pre-acquisition or Reeder for RSS — we'll comply with any specific
   trademark request and have already disclaimed affiliation in our
   listing."

---

## App Store Connect record creation checklist

When you're ready to submit (separate from this code work):

- [ ] Bundle ID `blue.skymarshal.ios` registered at developer.apple.com
      → Identifiers (verify capabilities: none required for v1)
- [ ] App Store Connect → My Apps → New App
- [ ] Fill in: name, bundle ID, primary language (English-US), SKU
      (e.g. `SKYM-1.0.0`)
- [ ] Pricing: Free
- [ ] Category: Social Networking primary, Utilities secondary
- [ ] Age rating: 17+ (per the user-generated-content nature of
      Bluesky source data)
- [ ] App Privacy: Data Not Collected for every category
- [ ] App Review Information: paste the block above
- [ ] Marketing URL, Support URL, Privacy Policy URL: all three
      pointing under skymarshal.blue
- [ ] App icon (1024×1024 — already in repo at
      ios/Skymarshal/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png)
- [ ] Screenshots (6.9" mandatory, 6.1" mandatory; iPad optional)
      per the SCREENSHOTS.md storyboard
- [ ] App Preview video: skip for v1 (it's optional and adds review
      surface area)
- [ ] Build: archive from Xcode, upload via Transporter or Xcode's
      Organizer, wait for "Processing" to clear (5–30 min)
- [ ] Tap "Submit for Review"

Post-submission: average wait is 24–48h. Response in App Store Connect's
"App Review" section.

---

## If rejected

1. Don't take it personally. Most apps get rejected at least once.
2. Read the citation carefully — Apple references a specific guideline
   number (e.g., "5.1.1(v)"). The fix is almost always specific to that
   guideline.
3. Reply via Resolution Center within App Store Connect, not email.
4. If the rejection is "you don't comply with X" but you actually do,
   reply with "Hi App Review, we believe Skymarshal already complies
   with X — see [specific reference]." Be polite, factual, no
   adversarial framing.
5. If Resolution Center back-and-forth stalls (>3 cycles), request a
   call: in Resolution Center → "Request a phone call." Apple's review
   team in California will call back within 1–2 business days.
6. If a phone call doesn't resolve, escalate to App Review Board
   (button in Resolution Center) with a written argument.

Most likely rejection vectors for this app: 5.2.1 (trademark — preempted
by disclaimer in description), 1.1.6 (user content — N/A, only user's own
content), 4.2 (minimum functionality — comfortably exceeds threshold).
