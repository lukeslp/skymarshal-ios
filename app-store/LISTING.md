# Skymarshal — App Store listing

Last revised 2026-05-10. Paste these into App Store Connect when submitting.

---

## App name (30 chars)

```
Skymarshal
```

10 chars. Clean. Trademark-safe (no Bluesky in the name).

---

## Subtitle (30 chars)

```
Cleanup tool for Bluesky.
```

24 chars. Indexed for search. "Bluesky" here is descriptive use of the
network name, not a trademark claim — the same posture every third-party
Bluesky tool on the App Store uses. If reviewer pushback ever surfaces,
fall back to "Bluesky archive cleanup." (also 24 chars, also descriptive).

---

## Promotional text (170 chars, updateable without re-review)

```
Search every post, reply, repost, and like in your archive — tidy in bulk. Score your follow list for bots and inactive accounts. App password only, nothing tracked.
```

168 chars. Leads with the two value propositions in their natural order
(content first, follower-cleanup second — matches the in-app tab order).
Privacy posture last because it's table-stakes for power users.

For future updates, swap the lead sentence to highlight the new feature
and keep the privacy line as the consistent footer.

---

## Description (4000 char cap; this draft is ~2,200)

```
Skymarshal is air-traffic control for your Bluesky.

Find old posts you forgot you wrote. Catch the late-night replies you'd
rather not look at. Cull the followers you'd never have followed back.
Skymarshal scans your own Bluesky archive, scores it, and lets you tidy
in bulk — with the kind of confirmations a deletion deserves.

Built for power users who've used Bluesky long enough that "delete one
post at a time" stopped being acceptable.

────────────

CONTENT MANAGEMENT
• Search every post, reply, repost, and like you've ever made — keyword,
  content type, date range, engagement count, alt-text, presence of media.
• Inline media thumbnails so you can remember exactly which post you're
  looking at before you act.
• Swipe-delete one at a time, or Select All from a search result and
  delete a hundred at once.
• Multiple confirmation steps. Permanent deletions deserve them.
• Rate-limit aware — bulk deletes pause and retry instead of hammering
  the API and getting throttled.

FOLLOWER CLEANUP
• Pull your full follow list and score every account against six bot
  signals: mass-following, no posts, missing profile bits, suspiciously
  round numbers, very-new accounts flooding follows, and bad ratios.
• Flag inactive accounts (no posts in N days, configurable).
• Catch deleted accounts (handle.invalid).
• Sort by follower ratio, account age, post frequency, mutuality, or
  influence tier (mega, macro, micro, nano).
• Bulk unfollow with the same rate-limit safety net the bulk delete uses.

DYNAMIC SEARCH
• Filter to "with media" or "without media."
• Search alt-text alongside post text — finds that capybara post even
  when you didn't write the word "capybara."
• Combine date range + engagement bounds to surface "dead threads"
  (low engagement) or "old bangers" (high engagement, distant past).

PRIVACY
• Sign in with a Bluesky app password. Skymarshal never sees your real
  password — generate a disposable one in Bluesky's settings.
• No analytics. No tracking pixels. No third-party SDKs of any kind.
• No account on our end, no server we host. Your archive is fetched
  directly from Bluesky's public XRPC endpoints. Nothing leaves your
  phone.

────────────

WHO IT'S FOR
Power users with thousands of posts. Journalists. Public-facing accounts.
Anyone who wants their archive on their terms. Light users will find it
overkill — that's fine. Skymarshal is the second tool you reach for when
the first one isn't enough.

WHAT IT'S NOT
Not a Bluesky client. You can't post from Skymarshal. Not a network
growth tool. Not affiliated with Bluesky Social, PBC. The Bluesky logo,
butterfly mark, and "Bluesky" name are property of their owner;
Skymarshal is an independent third-party utility.

Made by a small studio. Questions: skymarshal@lukesteuber.com
```

The full block is under 2,300 chars, leaving 1,700 of headroom for
seasonal or feature-specific additions.

Three rules respected:
- No "free", "best", "#1", "AI-powered", "AI-enhanced" — Apple bans these
  outright or treats them as smell.
- No competitor mentions other than the one we're built for (Bluesky).
- Affiliation disclaimer is explicit and last in its section so a
  reviewer skimming for trademark issues lands on it without searching.

---

## Keywords (100 char cap, comma-separated)

```
posts,replies,reposts,likes,archive,manage,delete,follower,unfollow,bot,atproto,bulk,clean,filter
```

98 chars. Indexes are additive: words in the app name + subtitle are
ALSO indexed for search, so this field shouldn't repeat
"skymarshal" / "cleanup" / "tool" / "bluesky".

Targeted searches this surfaces for:
- "bluesky cleanup" (subtitle + this field)
- "delete bluesky posts" (subtitle + delete + posts)
- "bluesky bot follower" (subtitle + bot + follower)
- "atproto archive manage" (atproto + archive + manage)

Words deliberately not included and why:
- `account`, `social`, `media` — too generic, low conversion
- `unfollow` is included but also reachable via "follower" stem
- `dorks` — would match the web app's "for dorks" tagline but unhelpful
  for App Store search intent

---

## What's New (4000 char cap; first version)

```
First flight.

Skymarshal does two things: searches every post, reply, repost, and like
in your Bluesky archive, and scores your follow list for bots and
inactive accounts. Bulk delete and bulk unfollow on top, with the
rate-limit safety nets they deserve.

App password only. No tracking. No server. Your archive stays on your
phone.
```

For subsequent versions, replace with a 1–3 sentence summary of the
release's marquee feature. Keep the "App password only…" line as a
permanent footer in update notes — repetition is reassuring, not stale.

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
