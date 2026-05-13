# Consensus run — Skymarshal iOS (2026-05-13)

Advisory only. Prompt: **`/tmp/consensus-skymarshal-ios.txt`** and repo copy [`consensus-skymarshal-ios-PROMPT.txt`](consensus-skymarshal-ios-PROMPT.txt).

## Transports

| Transport | Result |
|-----------|--------|
| **Gemini CLI** (`gemini -m gemini-2.5-flash -p …`) | **Skipped** — no useful stdout within automation time budget (process appeared hung / no completion in session). Re-run locally. |
| **Codex CLI** (`codex exec --skip-git-repo-check`, read-only sandbox) | **Skipped** — same (no completion in session). Re-run locally. |
| **Cursor-agent** | **Skipped** — `Authentication required` (no `CURSOR_API_KEY` / `agent login`). |
| **API fallback** (xAI / OpenAI / Mistral / Perplexity) | **Skipped** — `~/documentation/API_KEYS.md` not available in this environment. |

## Verdict matrix

| # | Question | Gemini | Codex | Cursor-agent | Session synthesis (advisory) |
|---|----------|--------|-------|--------------|----------------------------|
| Q1 | Default-OFF for grammar / Scope / backup / word patterns vs more ON for GTM | Skipped | Skipped | Skipped | **AGREE** — reduces App Review surface, support load, and “unfinished product” misread while power users can opt in via Feature lab. |
| Q2 | Scope stays TabView tab vs sheet-from-Insights | Skipped | Skipped | Skipped | **WAIT** — tab is discoverable for those who enable the flag; failure mode: casual users who flip Scope on see a sparse third tab and churn. Worth A/B after telemetry. |
| Q3 | Feature lab in About sufficient vs Labs on Content chrome | Skipped | Skipped | Skipped | **DISAGREE** — failure mode: experiment toggles stay invisible to most; add a one-time tip or subtle Content entry if adoption matters. |
| Q4 | Highest-ROI next slice (A dry-run B BG jobs C polish D defer Scope) | Skipped | Skipped | Skipped | **C + partial A** framed as **AGREE** that **(c) list/row polish** is best ROI for perceived quality per engineering dollar next; **(a) content delete dry-run** as second priority for parity trust. **DISAGREE** with **(d)** deferring Scope entirely while flag-gated — low cost to keep if off by default. |
| Q5 | App Review risk manageable with current disclosure | Skipped | Skipped | Skipped | **AGREE** with vigilance — failure mode: optional import/graph copy drifts from `PrivacyInfo.xcprivacy`; gate copy on every release. |
| Q6 | One ship-beyond-tests | Skipped | Skipped | Skipped | **Manual destructive + import matrix** on a large real archive (or dedicated test account): bulk delete preflight matches executed deletes; backup round-trip does not corrupt SwiftData. |

### Notable objections (single-voice / synthesis)

- **Q3 (synthesis):** Burying labs in About optimizes calm first launch but **suppresses** opt-in features you want power users to find — concrete failure: zero Scope usage in TestFlight.
- **Q4 (synthesis):** Choosing polish over BG jobs assumes **foreground** load remains acceptable for target accounts; failure: 50k-post users still hit wall-time before polish pays off.

### `/team` kill criteria (cross-link)

Echo from council verdict: **ship-blocker** if `deletionURI` mapping or 429 backoff regresses; **pivot** if core demand is full client; **sunset** if AT contract + solo maintenance + revenue misalign.

**Confidence (synthesis row):** medium — external voices unavailable this run.

## Prompt (canonical copy)

Identical to `/tmp/consensus-skymarshal-ios.txt`. Repo copy: [`consensus-skymarshal-ios-PROMPT.txt`](consensus-skymarshal-ios-PROMPT.txt).