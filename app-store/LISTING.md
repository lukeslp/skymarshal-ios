# Skymarshal — App Store listing

Last revised 2026-07-19. Paste these into App Store Connect when submitting.

Reconciliation note (2026-05-12): canonical execution now lives in
`APP_STORE_CONNECT_PASTE_SESSION.md` and canonical field values live in
`PUBLIC_RELEASE_COPY.md`. This file remains the detailed rationale record.

---

## App name (30 chars)

```
Skymarshal
```

10 chars. Clean. Trademark-safe (no Bluesky in the name).

---

## Subtitle (30 chars)

```
Bulk delete posts & follows
```

27 chars. Action-forward, no brand reference.

**Revised 2026-06-18 after a Guideline 4.1(a) "Copycats" rejection** of
1.0 (25). The prior subtitle "Cleanup tool for Bluesky." was cited
explicitly: Apple treats the platform name in the subtitle as a
misleading association even though it's descriptive use. The lesson:
keep "Bluesky" OUT of the subtitle entirely — do NOT use the
once-suggested "Bluesky archive cleanup" fallback, which would re-trip
the same rule. The platform is conveyed by screenshots, the review
notes, and a single functional mention in the description.

---

## Promotional text (170 chars, updateable without re-review)

```
Search and safely clean your archive. Private widgets surface rising posts worth joining, your top post, and clear follower trends. Nothing tracked.
```

Leads with safe archive cleanup, then makes the five network-free widgets
the update hook. Privacy posture remains the closing promise.

For future updates, swap the lead sentence to highlight the new feature
and keep the privacy line as the consistent footer.

---

## Description (4000 char cap; this draft is ~2,200)

```
Skymarshal is an independent cleanup utility for your account on Bluesky.
Search every post, reply, repost, and like you've ever made, then tidy it
in bulk, with the kind of confirmations a permanent deletion deserves.

Not affiliated with, endorsed by, or sponsored by Bluesky Social PBC.
Skymarshal is a third-party tool; all trademarks belong to their owners.

Built for power users who've been around long enough that "delete one post
at a time" stopped being acceptable.

────────────

CONTENT MANAGEMENT
• Search every post, reply, repost, and like you've ever made: keyword,
  content type, date range, engagement count, alt-text, presence of media.
• Inline media thumbnails so you can remember exactly which post you're
  looking at before you act.
• Swipe to delete one at a time, or Select All from a search result and
  delete a hundred at once.
• Multiple confirmation steps. Permanent deletions deserve them.
• Rate-limit aware: bulk deletes pause and retry instead of hammering
  the network and getting throttled.

FOLLOWER CLEANUP
• Pull your full follow list and score every account against six automation
  signals: mass-following, no posts, missing profile bits, suspiciously
  round numbers, very-new accounts flooding follows, and bad ratios.
• Flag inactive accounts (no posts in N days, configurable).
• Label unverified handles without treating them as deleted.
• Sort by follower ratio, account age, post frequency, mutuality, or
  influence tier (mega, macro, micro, nano).
• Bulk unfollow with the same rate-limit safety net the bulk delete uses.

DYNAMIC SEARCH
• Filter to "with media" or "without media."
• Search alt-text alongside post text; finds that capybara post even
  when you didn't write the word "capybara."
• Combine date range + engagement bounds to surface "dead threads"
  (low engagement) or "old bangers" (high engagement, distant past).

FIVE PRIVATE WIDGETS
• Worth Joining surfaces rising posts from people who regularly engage
  with you, balancing that relationship with current post momentum.
• Follow Snapshot shows follower, following, and inactive-account counts.
• Your Top Post clearly shows engagement on one of your own posts.
• Follower Trend keeps a simple recent-count sparkline on your Home Screen.
• Join In puts one timely conversation on your Home or Lock Screen.
• Widgets read a snapshot written by the app after a scan. The extension
  makes no network requests of its own and adds no new tracking.

PRIVACY
• Sign in with an app password, not your main password. Generate a
  disposable one in your account settings and revoke it whenever you like.
• No analytics. No tracking pixels. No third-party SDKs of any kind.
• No account on my end, no server I host. Your archive is fetched
  directly from the network's public endpoints. Nothing leaves your phone.

────────────

WHO IT'S FOR
Power users with thousands of posts. Journalists. Public-facing accounts.
Anyone who wants their archive on their terms. Light users will find it
overkill. That's fine. Skymarshal is the second tool you reach for when
the first one isn't enough.

WHAT IT'S NOT
Not a social client. You can't post from Skymarshal. Not a network-growth
tool. Just careful, bulk cleanup of the archive you already made.

Made by Luke Steuber. Questions: skymarshal@lukesteuber.com
```

The full block is well under the cap, leaving ample headroom for
seasonal or feature-specific additions.

Four rules respected:
- No "free", "best", "#1", "AI-powered", "AI-enhanced" — Apple bans these
  outright or treats them as smell.
- "Bluesky" appears exactly twice: one functional mention in the opening
  line and one in the non-affiliation disclaimer. **Revised 2026-06-18:**
  the prior draft used the brand ~7× and framed the product around it
  ("air-traffic control for your Bluesky"); Apple cited the description
  under 4.1(a) even though the disclaimer was present. Density of brand
  references reads as misleading association — keep it minimal.
- Non-affiliation disclaimer is now in the SECOND paragraph (front-loaded,
  not buried in "WHAT IT'S NOT") so a reviewer skimming for trademark
  issues lands on it immediately.
- "WHAT IT'S NOT" no longer restates the trademark notice (it's up top) and
  drops the logo/butterfly/name enumeration, which only added brand density.

---

## Keywords (100 char cap, comma-separated)

```
posts,replies,reposts,likes,archive,delete,follower,unfollow,widget,bulk,clean,filter,atproto
```

93 chars. Indexes are additive: words in the app name + subtitle are
ALSO indexed for search. The subtitle no longer carries "bluesky"
(removed 2026-06-18, see Subtitle note), so brand-name discoverability now
rides on `atproto` here plus the single description mention.

Targeted searches this surfaces for:
- "delete posts" / "bulk delete" (subtitle + delete + posts + bulk)
- "atproto archive manage" (atproto + archive + manage)
- "unfollow / follower cleanup" (follower + unfollow + clean)

Note: `bot` was removed from this field on 2026-06-18 to match the
user-facing "automation signals" rename and the actual `keywords.txt`.
"bluesky" is deliberately NOT a keyword — after the 4.1(a) rejection,
adding the brand to an indexed field would invite the same objection.

Words deliberately not included and why:
- `account`, `social`, `media` — too generic, low conversion
- `unfollow` is included but also reachable via "follower" stem
- `dorks` — would match the web app's "for dorks" tagline but unhelpful
  for App Store search intent

---

## What's New (4000 char cap; v1.0.2)

```
Five new widgets keep useful signals close without vague scores or obligation.

• Worth Joining: rising posts from people who regularly engage with you
• Join In: one timely conversation on your Home or Lock Screen
• Follow Snapshot: clear follower, following, and inactive-account counts
• Your Top Post: engagement on one of your own posts
• Follower Trend: a simple recent-count sparkline
• Clearer account signals, including neutral handling of unverified handles

Recommendations balance existing engagement with recent post momentum. The
widget extension reads an on-device snapshot and makes no network requests.
App password only. No tracking. No server.
```

Keep the "App password only…" line as a permanent footer in update notes —
repetition is reassuring, not stale.

---

## Category + age + privacy nutrition labels

- **Primary category:** Social Networking
- **Secondary category:** Utilities
- **Age rating:** 17+ (because user-generated content from Bluesky may
  include any rating; mark Frequent/Intense Mature/Suggestive Themes
  honestly to avoid 1.1.6 rejection later)
- **Content rights:** Yes — user owns and is responsible for the content
  they manage; we don't display third-party content
- **Privacy nutrition labels:**
  - Data Used to Track You: **None**
  - Data Linked to You: **None**
  - Data Not Linked to You: **None**
  - "Data Not Collected" is the truthful answer for every category.
    Be precise — "we don't have a server" is the underlying reason,
    not "we promise to be careful."

---

## Promotional URLs

- **Marketing URL:** https://skymarshal.blue
  (you already own this domain — point it at a static landing page
  with the same copy as the description, plus a "Get on App Store"
  badge once approved)
- **Support URL:** https://skymarshal.blue/support
  (page with FAQ + email link; required by App Review even if it's
  just a mailto)
- **Privacy Policy URL:** https://skymarshal.blue/privacy
  (required for any app that authenticates a user. Because we collect
  nothing, the policy can be one page: "Skymarshal does not collect,
  store, or transmit any of your data. App password is held in iOS
  Keychain on your device. Bluesky communications go directly from
  your device to bsky.social and public.api.bsky.app." Plus contact
  info.)

---

## Tagline / one-liner (for press / social / featuring pitch)

```
Air-traffic control for your Bluesky.
```

Carries the brand metaphor (skymarshal = air marshal = aviation oversight).
Same line as the in-app login subtitle for consistency.

Alternate (longer): "Manifest, please. Skymarshal scans, scores, and
tidies your Bluesky archive — without ever seeing your password."
