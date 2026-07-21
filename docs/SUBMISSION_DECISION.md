# Submission decision checklist (Day 16+)

> **RESOLVED 2026-07-20:** Skymarshal 1.0.2 (build 40) was submitted, approved, and is **live in the App Store**. Login verified in production. This gate is closed; the checklist below is retained as the historical record.

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

## Latest verification (2026-07-18)

- **YES — gate 3:** 275 unit tests and 12 non-credential UI tests passed on the iPhone 17 simulator; `ScreenshotTest` remains a credentialed release operation.
- **YES — gates 5–6:** both required runbooks are present in `docs/`.
- **PENDING — gates 1, 2, and 4:** `docs/soak/` contains only the observation template; the ≥10k-content recording, trace, 429 scenario, and JWT mid-flow evidence have not been recorded.
- **PENDING — release ops:** verify App Store Connect state, reviewer credentials, screenshots, and paste-session readiness externally before checking these boxes.

## Release-ops (Bucket D)

| Item | Status | Doc |
|------|--------|-----|
| Bundle ID + ASC record | ☐ | [app-store/SUBMISSION_NOTES.md](../app-store/SUBMISSION_NOTES.md) |
| Demo account `skymarshal-review.bsky.social` | ☐ | [app-store/DEMO_ACCOUNT.md](../app-store/DEMO_ACCOUNT.md) |
| 14 screenshots captured | ☐ | [app-store/SCREENSHOTS.md](../app-store/SCREENSHOTS.md) |
| Paste session prepared | ☐ | [app-store/APP_STORE_CONNECT_PASTE_SESSION.md](../app-store/APP_STORE_CONNECT_PASTE_SESSION.md) |

## Decision

- [x] **Submit to App Store** — submitted and approved; live as of 2026-07-20 (1.0.2, build 40).
- [ ] **Open-link public TestFlight only** — soak or runbooks incomplete; re-evaluate in 30 days (cynic dissent path).
- [ ] **Fix-and-resoak** — failure in observation note.

**Signed / date:** Luke Steuber / 2026-07-20
