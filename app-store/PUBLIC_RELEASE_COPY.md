# Skymarshal iOS Public Release Copy

Last updated: 2026-07-19 (reconciled against native 1.0.2)

Paste these values directly into App Store Connect for the public iOS release.

## App Store Connect Metadata

### App Name (30 max)

`Skymarshal`

### Subtitle (30 max)

`Bulk delete posts & follows`

### Promotional Text (170 max)

`Search and safely clean your archive. Private widgets surface rising posts worth joining, your top post, and clear follower trends. Nothing tracked.`

### Keywords (100 max, comma-separated)

`posts,replies,reposts,likes,archive,delete,follower,unfollow,widget,bulk,clean,filter,atproto`

### Description (4000 max)

Skymarshal is an independent cleanup utility for your account on Bluesky.
Search every post, reply, repost, and like you've ever made, then tidy it
in bulk, with the kind of confirmations a permanent deletion deserves.

Not affiliated with, endorsed by, or sponsored by Bluesky Social PBC.
Skymarshal is a third-party tool; all trademarks belong to their owners.

Built for power users who've been around long enough that "delete one post
at a time" stopped being acceptable.

CONTENT MANAGEMENT
- Search every post, reply, repost, and like you've ever made: keyword,
  content type, date range, engagement count, alt-text, presence of media.
- Inline media thumbnails so you can remember exactly which post you're
  looking at before you act.
- Swipe to delete one at a time, or Select All from a search result and
  delete a hundred at once.
- Multiple confirmation steps. Permanent deletions deserve them.
- Rate-limit aware: bulk deletes pause and retry instead of hammering
  the network and getting throttled.

FOLLOWER CLEANUP
- Pull your full follow list and score every account against six automation
  signals: mass-following, no posts, missing profile bits, suspiciously
  round numbers, very-new accounts flooding follows, and bad ratios.
- Flag inactive accounts (no posts in N days, configurable).
- Label unverified handles without treating them as deleted.
- Sort by follower ratio, account age, post frequency, mutuality, or
  influence tier (mega, macro, micro, nano).
- Bulk unfollow with the same rate-limit safety net the bulk delete uses.

DYNAMIC SEARCH
- Filter to "with media" or "without media."
- Search alt-text alongside post text; finds that capybara post even
  when you didn't write the word "capybara."
- Combine date range + engagement bounds to surface "dead threads"
  (low engagement) or "old bangers" (high engagement, distant past).

FIVE PRIVATE WIDGETS
- Worth Joining surfaces rising posts from people who regularly engage
  with you, balancing that relationship with current post momentum.
- Follow Snapshot shows follower, following, and inactive-account counts.
- Your Top Post clearly shows engagement on one of your own posts.
- Follower Trend keeps a simple recent-count sparkline on your Home Screen.
- Join In puts one timely conversation on your Home or Lock Screen.
- Widgets read a snapshot written by the app after a scan. The extension
  makes no network requests of its own and adds no new tracking.

PRIVACY
- Sign in with an app password, not your main password. Generate a
  disposable one in your account settings and revoke it whenever you like.
- No analytics. No tracking pixels. No third-party SDKs of any kind.
- No account on my end, no server I host. Your archive is fetched
  directly from the network's public endpoints. Nothing leaves your phone.

WHO IT'S FOR
Power users with thousands of posts. Journalists. Public-facing accounts.
Anyone who wants their archive on their terms. Light users will find it
overkill. That's fine. Skymarshal is the second tool you reach for when
the first one isn't enough.

WHAT IT'S NOT
Not a social client. You can't post from Skymarshal. Not a network-growth
tool. Just careful, bulk cleanup of the archive you already made.

Made by Luke Steuber. Questions: skymarshal@lukesteuber.com

### What's New (v1.0.2)

Five new widgets keep useful signals close without vague scores or obligation.

- Worth Joining: rising posts from people who regularly engage with you
- Join In: one timely conversation on your Home or Lock Screen
- Follow Snapshot: clear follower, following, and inactive-account counts
- Your Top Post: engagement on one of your own posts
- Follower Trend: a simple recent-count sparkline
- Clearer account signals, including neutral handling of unverified handles

Recommendations balance existing engagement with recent post momentum. The
widget extension reads an on-device snapshot and makes no network requests.
App password only. No tracking. No server.

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
