# Submission decision checklist (Day 16+)

Use after Week 1–3 engineering + soak work. **Do not edit the council plan file** — this is the operational gate.

## Ship-blockers (all must be YES to submit to App Store)

| # | Gate | Evidence |
|---|------|----------|
| 1 | ≥10k-post soak artifact committed under `docs/soak/` | `run1-*-OBSERVATION.md` + recording + trace |
| 2 | 429 backoff not regressed in soak | Scenario 2 pass in observation |
| 3 | `DeleteURIMappingTests` + full unit suite green | CI or local `xcodebuild test` |
| 4 | JWT mid-flow scenario pass | Scenario 3 in observation |
| 5 | [XRPC_DRIFT_RUNBOOK.md](XRPC_DRIFT_RUNBOOK.md) committed | this repo |
| 6 | [PUBLIC_RESPONSE_PLAYBOOK.md](PUBLIC_RESPONSE_PLAYBOOK.md) committed | this repo |

## Release-ops (Bucket D)

| Item | Status | Doc |
|------|--------|-----|
| Bundle ID + ASC record | ☐ | [app-store/SUBMISSION_NOTES.md](../app-store/SUBMISSION_NOTES.md) |
| Demo account `skymarshal-review.bsky.social` | ☐ | [app-store/DEMO_ACCOUNT.md](../app-store/DEMO_ACCOUNT.md) |
| 14 screenshots captured | ☐ | [app-store/SCREENSHOTS.md](../app-store/SCREENSHOTS.md) |
| Paste session prepared | ☐ | [app-store/APP_STORE_CONNECT_PASTE_SESSION.md](../app-store/APP_STORE_CONNECT_PASTE_SESSION.md) |

## Decision

- [ ] **Submit to App Store** — all ship-blockers YES, paste session executed.
- [ ] **Open-link public TestFlight only** — soak or runbooks incomplete; re-evaluate in 30 days (cynic dissent path).
- [ ] **Fix-and-resoak** — failure in observation note.

**Signed / date:** _______________
