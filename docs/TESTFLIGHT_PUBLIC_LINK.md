# Open-link public TestFlight

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

Use when soak artifacts or cynic runbooks are **not** ready but you want real-user signal without burning App Store first impression.

## When to choose this path

- Soak Run 1 not complete → **do not** submit to App Store (kill criterion #1)
- [PUBLIC_RESPONSE_PLAYBOOK.md](PUBLIC_RESPONSE_PLAYBOOK.md) or [XRPC_DRIFT_RUNBOOK.md](XRPC_DRIFT_RUNBOOK.md) missing
- Skeptic gate: prefer **30 days** on public TestFlight after soak passes

## Steps

1. Upload build to App Store Connect (same as release build).
2. TestFlight → External Testing → create group **Public**.
3. Enable **Public Link** (open invitation).
4. Add What’s New (literal, no "AI" copy).
5. Submit build for **Beta App Review** (required for external testers).
6. Share link only after Beta App Review approves.

## Exit to App Store

Complete [SUBMISSION_DECISION.md](SUBMISSION_DECISION.md) — all ship-blockers YES — then submit for App Review on same or newer build.

## 1-week fallback (plan)

If only polish + ASC scaffolding fit in one week: ship **this** public TF link on current build while finishing soak the following week.
