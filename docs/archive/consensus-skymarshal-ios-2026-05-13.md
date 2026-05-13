# Consensus run — Skymarshal iOS (2026-05-13)

Advisory only. Prompt: **`/tmp/consensus-skymarshal-ios.txt`** (if present) and repo copy [`consensus-skymarshal-ios-PROMPT.txt`](consensus-skymarshal-ios-PROMPT.txt).

**Re-run Codex** (stdin form avoids “Reading additional input from stdin” hang when the prompt is long):

```bash
cd /path/to/skymarshal-ios
cat docs/archive/consensus-skymarshal-ios-PROMPT.txt | codex exec --skip-git-repo-check -c 'sandbox_mode="read-only"' -
```

**Re-run Claude Code:**

```bash
claude -p "$(cat docs/archive/consensus-skymarshal-ios-PROMPT.txt)" --output-format text
```

Raw transcripts: [`consensus-raw-codex-2026-05-13.txt`](consensus-raw-codex-2026-05-13.txt), [`consensus-raw-claude-2026-05-13.txt`](consensus-raw-claude-2026-05-13.txt).

## Transports

| Transport | Result |
|-----------|--------|
| **Gemini CLI** | **Failed** — prior attempt returned HTTP **499 CANCELLED** from Code Assist stream (`backendError`); no Q1–Q6 text. Re-run in a full terminal / retry. |
| **Codex CLI** | **Completed** — `gpt-5.5`, read-only sandbox; see raw file. |
| **Claude Code CLI** (`claude -p`) | **Completed** — see raw file. |
| **Cursor-agent** | **Skipped** — auth required. |
| **API curl fallback** | **Skipped** — no keys file in automation environment. |

## Verdict matrix

| # | Topic | Gemini | Codex (gpt-5.5) | Claude Code | Merged read |
|---|-------|--------|-----------------|-------------|-------------|
| Q1 | Default-OFF experiments for GTM | Failed | **AGREE** | **AGREE** | **Unanimous AGREE** — keep power tools opt-in for App Store / first-run clarity. |
| Q2 | Scope as third tab vs sheet-from-Insights | Failed | **AGREE** (tab when enabled) | **DISAGREE** (sheet first; pill bar cost) | **Split** — ship telemetry: if Scope enable-rate is low, try sheet-first; if power users want a home, keep tab. |
| Q3 | Feature lab in About enough vs Labs on Content | Failed | **DISAGREE** (need clearer entry) | **AGREE** (About + menus; no Labs chip) | **Split** — compromise: **non-chrome** discoverability (one-time tip, release note, or “New in Skymarshal” row) without a permanent Labs chip. |
| Q4 | Next ROI slice A/B/C/D | Failed | **B** + AGREE | **B** + AGREE | **Unanimous: (b) background refresh / checkpoints** before arguing polish vs dry-run for large-account spine. |
| Q5 | App Review risk manageable | Failed | **WAIT** (needs explicit copy/labels) | **WAIT** (import scope + nutrition label) | **Unanimous WAIT** — tighten privacy copy + import handle scoping **before** submission. |
| Q6 | Ship-blocker beyond tests | Failed | Large-account soak (pagination, 429, dry-run, confirms) | Real-device soak + **screen recording**; resume-after-suspend | **Converge on large-account / real-device soak**; Claude adds **recording** and **resume** failure mode. |

### Notable objections (preserve dissent)

- **Claude Q2:** Third tab burns **iOS 26 tab bar** attention on a flag-gated surface; empty Scope → churn before delete wins.
- **Codex Q3:** Without a clearer entry than About, **TestFlight power users miss** enabled experiments.
- **Claude Q5:** Wrong-handle JSON import → **5.1.2 / privacy label mismatch** rejection narrative.
- **Claude Q6:** **Mid-batch suspension** loses in-memory delete queue — unit tests won’t catch; needs product/UX answer for resume.

### `/team` kill criteria (cross-link)

**Ship-blocker** if `deletionURI` mapping or 429 backoff regresses; **pivot** if core demand is full client; **sunset** if AT contract + solo maintenance + revenue misalign.

**Confidence (merged):** **high** on Q1 and Q4; **medium** on Q2–Q3 and Q6 until telemetry and soak evidence land.

## Prompt (canonical copy)

[`consensus-skymarshal-ios-PROMPT.txt`](consensus-skymarshal-ios-PROMPT.txt)

---

## Appendix — Codex raw (gpt-5.5, read-only)

```
Q1: AGREE — Default-off keeps the core utility legible and reduces review, support, and onboarding risk.

Q2: AGREE — When enabled, Scope is broad enough to justify a real navigation home rather than being hidden behind Insights.

Q3: DISAGREE — Experiments need one clearer entry point outside About for opted-in users. Failure mode: power users miss enabled tools and assume parity features are absent during TestFlight.

Q4: B AGREE — Background refresh and checkpoint jobs are the best default next slice because large-account reliability affects the core archive workflow.

Q5: WAIT — It is manageable only after privacy labels, import wording, and review notes explicitly state local-only processing. Failure mode: App Review interprets optional imports or graph analysis as collected user data.

Q6: AGREE — Ship-blocker gate: a large-account TestFlight soak covering pagination resume, 429 backoff, dry-run, and destructive confirmation paths.

Confidence: high
```

---

## Appendix — Claude Code raw (`claude -p`, print)

```
Q1: AGREE — Default-off keeps the App Store reviewer's first-run flow simple (login → list → filter → delete) while still giving power users the surface, which matches Apple's "progressive disclosure" expectations for utilities.

Q2: DISAGREE — A third TabView tab spends scarce iOS 26 pill-bar real estate on a feature that's flag-gated and unproven; promote to a tab only after Insights-sheet entry shows engagement. Failure mode: TestFlight users see a "Scope" tab they never enabled, tap it once, see a placeholder/empty graph because they haven't loaded enough data yet, and churn before reaching the actual delete flow.

Q3: AGREE — About → Feature lab plus per-screen menu toggles is the conventional Apple pattern (mirrors Safari's Advanced/Experimental settings); a persistent "Labs" chip on Content chrome would dilute the "air-traffic control" brand voice.

Q4: B — AGREE — Background refresh / checkpoint jobs for large accounts is the right next slice because the 50k-post + 5k writes/hr PDS ceiling is the one failure mode that turns a five-star review into a one-star ("app gave up halfway"), and a/c/d are polish layered on top of a reliable bulk-delete spine.

Q5: WAIT — Disclosure is probably fine, but "Data Not Collected" plus a JSON backup import path needs the import to be explicitly scoped to the signed-in handle and documented in the privacy nutrition label's "Data Used to Provide the Service / Not Linked". Failure mode: a reviewer imports a JSON containing a different handle's content, the app displays/deletes against the wrong account context, and the rejection cites Guideline 5.1.2 (data minimization) plus a privacy-label mismatch.

Q6: WAIT — Insist on a real-device large-account soak test (≥10k items, full filter → bulk delete → resume after 429 storm) signed off with a screen recording, because XCTest unit coverage won't catch the backoff/checkpoint interaction that defines this app's identity. Failure mode: the 429 retry chain works in isolation tests but a mid-batch app suspension on a real iPhone loses the in-memory delete queue, the user opens the app to a half-deleted archive with no resume affordance, and TestFlight feedback lights up.

Confidence: medium
```
