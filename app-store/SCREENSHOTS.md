# Skymarshal — App Store screenshot storyboard

Last revised 2026-05-10. Capture against iPhone 17 Pro (6.9") and
iPhone 16e or similar 6.1"; Apple wants both sizes for new submissions.
iPad screenshots are optional — skip until v1.1 unless you want the
listing to mark "Designed for iPad."

The first **3 frames** are visible without the user tapping "more" —
they have to carry the value story.

---

## Frame 1 — Hero / brand

**Caption:** "Manifest, please."
**Subline:** "Search every post, reply, repost, and like in your Bluesky archive."

**What's on screen:** the post-login Content tab with a non-trivial
search ("trump") active, scope chip on "All", load progress banner
showing "11,074 loaded · scanning posts and replies", and three to four
visible AccountRow / ContentRow items. (Use the screenshot the user
already shipped during testing as the model — it's exactly this.)

**Why this frame is first:** opens with motion (live count), visible
filter machinery (chip row), and the unique product promise (sweeping
through thousands at once). No abstract glamour shot — straight to the
work.

---

## Frame 2 — Find anything

**Caption:** "Find anything in your archive."
**Subline:** "Date, engagement, alt-text, media-only. Combine as needed."

**What's on screen:** the FilterSheet open over a dimmed list. Show
"Photos & video" picker set to "With media", "Search alt text too" toggle
on, dates section with "After…" toggled and a recent date picked, and
the Likes min/max paired inputs filled with "0" / "5" (the dead-threads
hunt).

**Why:** demonstrates that "search" is more than keyword matching. The
filter sheet is one of the biggest design wins in the app and most
users won't realize it exists from the home screen alone.

---

## Frame 3 — Clean house

**Caption:** "Clean house — by the numbers."
**Subline:** "Six bot signals, calibrated. Inactive accounts surfaced. Bulk unfollow."

**What's on screen:** the Followers tab post-scan. Top: ScanSummaryStrip
in full color: `[1,247 analyzed] [89 bots] [412 inactive] [156 mutuals]
[78 deleted] [34 bad ratio]`. Below: 3-4 AccountRow items with visible
BotScoreBadges (red/orange variants), one mutual icon, one inactive flag,
one deleted account.

**Why:** introduces the second tab as a coequal value proposition. The
summary strip is the most information-dense surface in the app and
reads beautifully in a screenshot.

---

## Frame 4 — Selection in flight

**Caption:** "Pick precisely. Or pick a hundred."
**Subline:** "Select All from any search result, then delete in one move."

**What's on screen:** Content tab in EditMode with 47 items selected
(visible blue tinted rows from the listRowBackground tint), the
EditActionBar visible at the top showing "✓ Deselect All · 47 selected ·
Delete", and the active "trump" filter chip above. Search keyword shown
in the search field.

**Why:** the search-then-bulk-act flow is the killer feature. This frame
demonstrates the safety pattern (visible selection + count) and the
scale (47 from a long list).

---

## Frame 5 — Permanent means permanent

**Caption:** "Permanent means permanent."
**Subline:** "Multi-step confirmation. Rate-limit aware. No surprises."

**What's on screen:** the bulk-delete confirmationDialog presenting
"Delete 47 items?" with the warning copy ("47 items leaves the building.
There's no carry-on for this — deletion is permanent.") and Delete
(destructive red) + Cancel buttons.

**Why:** addresses the "I'm worried about losing data" objection
directly. Apple reviewers also like seeing destructive-action
confirmations — it short-circuits 4.0 design-quality concerns.

---

## Frame 6 — Read the room

**Caption:** "Read the room."
**Subline:** "Each account scored across six signals. Tap to inspect."

**What's on screen:** Followers tab list zoomed in on a few rows showing
the leading colored stripe by status (red bot, orange suspect, yellow
inactive, accent mutual), avatars, BotScoreBadges with percentages, and
the metric row (followers/following/ratio + tier).

**Why:** the analyzer is the technical signature of the product. Showing
multiple distinct row colors in one frame is the most efficient way to
communicate "this app does real work, not just chrome."

---

## Frame 7 — Privacy posture

**Caption:** "App password only. Nothing tracked."
**Subline:** "Your archive stays on your phone. No server, no analytics, no SDKs."

**What's on screen:** the LoginView. Centered scope glyph + concentric
rings, "Skymarshal" wordmark, "Air-traffic control for your Bluesky."
subtitle, "Climb aboard" section header, app-password explanation,
disabled "Sign in" button. Dark mode preferred — the scope motif glows.

**Why:** privacy is the closing argument. Light users care less; the
power users this app targets care a lot. Putting it last lets the
buyers who are convinced by frames 1–3 stop scrolling, and lets the
buyers who are wary by frame 5 be reassured by frame 7.

---

## Optional 8th frame — App icon at scale (skip for v1)

If Apple ever lets you put a brand-only frame in the carousel, the
scope-rings AppIcon at 1024 with no other UI is striking — but for a
first submission, devote every frame to a unique value claim instead.

---

## Capture instructions

```bash
# Boot a sim, log in with a real account, navigate to each state
xcrun simctl boot "iPhone 17 Pro"
# (do the captures via the iPhone simulator's File → New Screen Shot,
#  which produces the device-frame-free 1206x2622 PNGs Apple expects)

# Confirm dimensions:
sips -g pixelWidth -g pixelHeight ~/Desktop/Skymarshal-frame-*.png
```

Apple now accepts frame-free screenshots; if you want device frames,
generate them via [Apple's Marketing Tools](https://developer.apple.com/app-store/marketing/guidelines/)
or skip and let App Store Connect render the device chrome.

Localizations: English-US is enough for v1. Add additional locales only
when telemetry shows demand.

---

## Caption typography

If you composite captions ON the screenshots (some teams do, some don't):
- Display font: SF Pro Display, Bold, 64 pt at 6.9" (scales with device)
- Subline: SF Pro Text, Regular, 28 pt
- Color: white on top 30 % of image with a subtle drop-shadow OR black
  on bottom 30 %; respect the screenshot's dominant area
- Don't overlay the search bar or the scope glyph

If you don't composite captions, App Store Connect's "Custom Product Pages"
can carry per-page caption text — same six taglines, same order.
