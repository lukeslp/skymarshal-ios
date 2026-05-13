# Skymarshal iOS Public Release Copy

Last updated: 2026-05-12 (reconciled)

Paste these values directly into App Store Connect for the public iOS release.

## App Store Connect Metadata

### App Name (30 max)

`Skymarshal`

### Subtitle (30 max)

`Cleanup tool for Bluesky.`

### Promotional Text (170 max)

`Search every post, reply, repost, and like in your archive — tidy in bulk. Score your follow list for bots and inactive accounts. App password only, nothing tracked.`

### Keywords (100 max, comma-separated)

`posts,replies,reposts,likes,archive,manage,delete,follower,unfollow,bot,atproto,bulk,clean,filter`

### Description (4000 max)

Skymarshal is air-traffic control for your Bluesky.

Find old posts you forgot you wrote. Catch the late-night replies you'd
rather not look at. Cull the followers you'd never have followed back.
Skymarshal scans your own Bluesky archive, scores it, and lets you tidy
in bulk — with the kind of confirmations a deletion deserves.

Built for power users who've used Bluesky long enough that "delete one
post at a time" stopped being acceptable.

CONTENT MANAGEMENT
- Search every post, reply, repost, and like you've ever made — keyword,
  content type, date range, engagement count, alt-text, presence of media.
- Inline media thumbnails so you can remember exactly which post you're
  looking at before you act.
- Swipe-delete one at a time, or Select All from a search result and
  delete a hundred at once.
- Multiple confirmation steps. Permanent deletions deserve them.
- Rate-limit aware — bulk deletes pause and retry instead of hammering
  the API and getting throttled.

FOLLOWER CLEANUP
- Pull your full follow list and score every account against six bot
  signals: mass-following, no posts, missing profile bits, suspiciously
  round numbers, very-new accounts flooding follows, and bad ratios.
- Flag inactive accounts (no posts in N days, configurable).
- Catch deleted accounts (handle.invalid).
- Sort by follower ratio, account age, post frequency, mutuality, or
  influence tier (mega, macro, micro, nano).
- Bulk unfollow with the same rate-limit safety net the bulk delete uses.

DYNAMIC SEARCH
- Filter to "with media" or "without media."
- Search alt-text alongside post text — finds that capybara post even
  when you didn't write the word "capybara."
- Combine date range + engagement bounds to surface "dead threads"
  (low engagement) or "old bangers" (high engagement, distant past).

PRIVACY
- Sign in with a Bluesky app password. Skymarshal never sees your real
  password — generate a disposable one in Bluesky's settings.
- No analytics. No tracking pixels. No third-party SDKs of any kind.
- No account on our end, no server we host. Your archive is fetched
  directly from Bluesky's public XRPC endpoints. Nothing leaves your
  phone.

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

### What's New (v1.0.0)

First flight.

Skymarshal does two things: searches every post, reply, repost, and like
in your Bluesky archive, and scores your follow list for bots and
inactive accounts. Bulk delete and bulk unfollow on top, with the
rate-limit safety nets they deserve.

App password only. No tracking. No server. Your archive stays on your
phone.

## TestFlight “What to try” (paste into build notes)

- **Archive refresh + interrupt:** Start a full archive load, background the app mid-pagination, return and confirm counts move forward without duplicate rows.
- **Bulk delete + 429:** Try a medium batch delete on a test account; confirm backoff feels steady and any interruption surfaces the recovery alert (pull to refresh afterward).
- **Scope:** Toggle **About → Feature lab → Scope tab**; open **Insights → Scope visualizations** when the tab is off (alternate entry).
- **Advanced search grammar / word patterns:** Enable in Feature lab, run a few saved filters.
- **Backup import (signed-in only):** Export JSON from Skymarshal, re-import merge/replace on a throwaway handle; confirm DID/handle mismatch **blocks** import.
- **Soak gate:** Follow [`docs/SOAK_PROTOCOL.md`](../docs/SOAK_PROTOCOL.md) before a public build; attach a device screen recording per checklist.

## App Review Information (Paste in Review Notes)

Use the full block from `SUBMISSION_NOTES.md` under:

- `App Review Information (paste verbatim into App Store Connect)`

## URL Fields

- Marketing URL: `https://skymarshal.blue`
- Support URL: `https://skymarshal.blue/support`
- Privacy Policy URL: `https://skymarshal.blue/privacy`

## Public Launch Copy Snippets

### One-liner

`Air-traffic control for your Bluesky.`

### Website Hero

Search everything you've posted on Bluesky, then clean up in bulk with safety rails built for real accounts.

### Social Post

Skymarshal for iOS is live. Search posts, replies, reposts, and likes across your Bluesky archive, then clean up in bulk. App password only. No tracking. https://skymarshal.blue

### Email Blurb

Skymarshal iOS is now available: a cleanup-first utility for Bluesky power users. Search your full archive, run high-precision filters, and bulk-delete or unfollow with built-in rate-limit and confirmation safeguards.
