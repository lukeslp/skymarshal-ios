# XRPC drift runbook

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**When to use:** Bluesky / atproto changes a lexicon, error code, or rate-limit behavior and Skymarshal starts failing in production or TestFlight.

**Owner:** Luke Steuber (solo maintainer).  
**Kill criterion:** Do not submit to the public App Store until this runbook exists in-repo (council gate, 2026-05-16).

---

## 1. Triage (first 30 minutes)

| Signal | Likely cause | First check |
|--------|----------------|-------------|
| Mass `401` / `ExpiredToken` after idle | Session refresh path | `ATProtoClient.perform`, Keychain `SessionStore` |
| `400` with new `error` string | Lexicon or validation drift | Compare response body to `ATProtoError` parsing |
| Deletes succeed in web/CLI but fail in app | Wrong `deletionURI` | `DeleteURIMappingTests`, like/repost viewer URIs |
| Sudden `429` storms | PDS policy change | `RateLimit.withBackoff` — **do not shorten backoff** |
| Empty feeds / zero items after load | Pagination cursor or endpoint rename | `ContentService.loopEndpoint`, archive checkpoints |

## 2. Reproduce locally

1. Note app version (`CFBundleShortVersionString` / `CFBundleVersion`).
2. Reproduce on **physical device** with the failing account (simulator OK for auth-only bugs).
3. Capture one failing XRPC: method name, request body (redact JWT), status, JSON error envelope.
4. Compare against `reference/python/` behavior on the same account (frozen upstream in this repo).

## 3. Fix boundaries (sacred — do not regress)

- **429 backoff:** `[1, 2, 4, 8, 15, 30, 60, 120]` seconds — per `RateLimit.swift`, matches Python `deletion.py`.
- **Deletion identity:** likes/reposts delete **viewer record URI**, not subject post URI — per `ContentItem.deletionURI`.
- **Engagement weights:** `1×L + 2×R + 2.5×Reply` — not TS web `1/2/3`.

## 4. Ship path

1. Patch `SkymarshalCore` (prefer `ATProtoClient` + typed decoders over view-layer hacks).
2. Add or extend unit test that would have caught the drift.
3. Run full suite from `ios/`: `xcodebuild test -scheme Skymarshal -destination 'platform=iOS Simulator,name=iPhone 17'`.
4. If behavior touches delete or bulk load: repeat **soak scenario 2 or 3** from [SOAK_PROTOCOL.md](SOAK_PROTOCOL.md).
5. TestFlight build → note in What's New (factual, no "AI" copy).

## 5. Communicate

- **TestFlight testers:** short note in release notes if user-visible.
- **App Store reviews / Bluesky:** use [PUBLIC_RESPONSE_PLAYBOOK.md](PUBLIC_RESPONSE_PLAYBOOK.md) tone — factual, accountable, no jargon.

## 6. When to freeze releases

- Any ambiguity on **which URI is deleted** → stop shipping; fix + soak first.
- Backoff removed or shortened → stop shipping.
- Cannot reproduce fix on device within 48h → stay on open-link TestFlight only.
