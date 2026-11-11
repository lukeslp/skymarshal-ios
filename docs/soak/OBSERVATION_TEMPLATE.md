# Soak observation — Run 1

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../../README.md).

**Date:** YYYY-MM-DD  
**Device:** (model, iOS version)  
**Build:** Skymarshal 1.0.0 (N)  
**Account:** handle + approximate post count  
**Tester:** Luke Steuber

## Environment

- Network: Wi‑Fi / cellular
- Fresh install or upgrade from prior TF build: 
- Keychain had prior session: yes / no

## Scenario 1 — Import resume

| Step | Result | Notes |
|------|--------|-------|
| Start full content load | pass / fail | |
| Force-quit at ~50% | | |
| Relaunch | pass / fail | dup count: |
| Row count vs pre-kill | pass / fail | |

## Scenario 2 — 429 backoff

| Step | Result | Notes |
|------|--------|-------|
| Delete batch ≥1000 | pass / fail | |
| Observed rate-limit pause | pass / fail | max backoff waited: |
| All intended records removed | pass / fail | |

## Scenario 3 — JWT expiry mid-flow

| Step | Result | Notes |
|------|--------|-------|
| Trigger expiry during load/delete | pass / fail | method: |
| Returned to login or refreshed | pass / fail | |
| No delete after auth invalid | pass / fail | |

## Cold launch (signposts)

- `hydrate_from_cache` wall time (subjective): 
- Main-thread spike &gt;100ms during hydrate: yes / no
- Attach trace file name: 

## Regressions noticed

- 

## Verdict

- [ ] **Pass** — OK to open public TestFlight link
- [ ] **Fail** — fix-and-resoak required before TF / App Store
