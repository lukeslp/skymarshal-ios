# Public response playbook

**Trigger:** A user posts publicly that Skymarshal deleted the wrong content, broke their account, or caused unexpected data loss — especially on Bluesky in month 1–2 after launch.

**Goal:** Respond within **24 hours** with calm, factual, accountable copy. No legal threats, no "AI", no internal tooling names.

**Kill criterion:** Do not submit to the public App Store until this document is committed (pre-ship gate, 2026-05-16).

---

## 1. First response (within 24h) — template

> Thanks for reporting this — I'm Luke, the developer of Skymarshal. I'm sorry this happened.
>
> Skymarshal deletes **your** records on Bluesky (posts, likes, reposts, replies) using the same APIs as the official apps; it does not delete other people's content. If something you expected to keep is gone, I want to understand exactly what you selected and what disappeared.
>
> Please DM or email me (luke@lukesteuber.com) with:
> - Your handle (if you're comfortable)
> - What you tapped (e.g. "delete 500 items matching …")
> - Rough time (timezone)
> - Whether you were on iOS TestFlight or App Store build [version]
>
> I'll investigate and follow up. If I confirm a bug, I'll document the fix and prioritize a TestFlight build.

**Customize:** Replace bracketed version; do not promise refunds unless applicable.

## 2. What NOT to say

- "The AI deleted…" / "AI-powered" (product rule: never use AI in user-facing prose)
- "It's Bluesky's fault" (even if PDS-related; lead with what *I* know)
- "You must have mis-tapped" (invalidating)
- Internal codenames, tool names, slash commands

## 3. Internal checklist (before replying)

- [ ] Confirm user's build version from crash logs or their report
- [ ] Check whether selection was **likes/reposts** (viewer URI) vs posts
- [ ] Check whether **typed confirm** (≥100 items) was shown
- [ ] Reproduce filter + delete path if they provide search terms
- [ ] Log issue in private tracker with `deletion-incident` label

## 4. If I confirm a bug

1. Fix + test (`DeleteURIMappingTests`, preflight counts, soak scenario 2).
2. TestFlight release with literal What's New: what was wrong, what I fixed.
3. Public follow-up on original thread: brief, link to update when live.

## 5. If I can't reproduce

> I wasn't able to reproduce this on my side with the steps you sent, but I'm keeping the report open. If you see it again on build [X], please capture a screen recording starting **before** you tap Delete — that helps enormously.

## 6. Escalation

- **Data loss on another user's account:** treat as P0 — pause marketing, open TestFlight-only until root-caused.
- **Legal / press contact:** reply acknowledging receipt; do not debate in public thread — move to email.

## 7. Prevention (product)

- Typed confirm for large batches (shipped)
- Delete preflight counts (shipped)
- Soak protocol ≥10k posts before public App Store ([SOAK_PROTOCOL.md](SOAK_PROTOCOL.md))
