## Consensus on architecture / cold-launch (external)

**Prompt (verbatim):**  
Skymarshal iOS SwiftUI app cold-launch freezes. Verdict each (AGREE/DISAGREE/WAIT + one line):

1. Main bottleneck is unbounded SwiftData fetch + in-memory filter in `hydrateFromCache` assigning huge arrays on MainActor.
2. `ContentListView` `filteredItems` (filter+sort O(n log n)) on every model invalidation is a major contributor on tab switch.
3. Single `@Observable` `AppModel` god-object must be split before other perf fixes.
4. Keychain `SessionStore.load` + session refresh network usually dominates SQLite for typical users.

**Voices:** Mistral `mistral-large-latest` (API)  
**Skipped:** OpenAI `gpt-5-mini` / `gpt-4o-mini` — `insufficient_quota`. xAI `grok-4-fast` — API key blocked for this workspace run.

### Mistral `mistral-large-latest` (raw)

1) **AGREE** - Large SwiftData fetches and in-memory filtering on the MainActor will block the UI during cold launch.  
2) **AGREE** - O(n log n) filtering/sorting on every model invalidation (especially on tab switches) is inefficient and noticeable.  
3) **WAIT** - Splitting the god-object may help, but other fixes (like 1 & 2) should be prioritized first.  
4) **DISAGREE** - Keychain/SessionStore is usually fast; SQLite/SwiftData overhead is more likely the dominant factor.

### Synthesis table

| # | Question | Mistral | Verdict |
|---|----------|---------|---------|
| 1 | Unbounded hydrate + MainActor assign | AGREE | **Treat as primary hypothesis** (matches internal trace plan). |
| 2 | `filteredItems` recompute on invalidation | AGREE | **High-confidence UI fix.** |
| 3 | Split god-object *before* anything else | WAIT | **Split after** predicate fetch + memoize — aligns with architect dissent in `ARCH_VERDICT`. |
| 4 | Keychain+network dominates SQLite | DISAGREE | **Contextual:** first launch / refresh path can dominate; large local DB disagrees. |

### Notable objections

- **Mistral on #4:** Keychain is usually fast — use Instruments to prove per-account whether **network refresh** or **SQLite** wins; do not assume globally.

### Internal note

When billing/API access returns, re-run the same prompt against **Grok** + **GPT** to preserve diversity of vendor priors; do not overwrite Mistral’s dissent.
