# /doubt — Paper zine / broadsheet direction (`riso_scope`)

> **Retired.** This document describes the native SwiftUI Skymarshal app, which reached end of life in November 2026. It is kept as written and is not maintained. See the [README](../README.md).

**Date:** 2026-05-15  
**Assumption:** Paper-zine is the **provisional front-runner** for “more stylized than default iOS” without going full CRT brutalism. This document is the **adversarial** pass — not a rejection, a stress test.

---

## Strongest attacks (concrete failure modes)

### 1. WCAG + Dynamic Type collision

**Mechanism:** Fraunces display + halftone texture + `Theme.Mono` metrics at **AX5** produces **competing textures** — serif counters fill in, halftone moirés on OLED at low brightness.

**Failure:** VoiceOver users hear correct labels but **sighted low-vision** users cannot scan the follower list fast enough for bulk cleanup — the core job-to-be-done.

### 2. Performance budget (texture + blur)

**Mechanism:** Full-screen `PaperNoiseTexture` in `List` behind 10k rows **invites overdraw** if implemented as a large `Image` + blend.

**Failure:** The aesthetic **amplifies** the cold-launch problem you’re trying to solve — **GPU time** replaces CPU time as the villain.

### 3. Brand dilution

**Mechanism:** Riso / Are.na visual language reads **“indie reader app”**, not **ATC / scope / airspace**.

**Failure:** App Store browser thinks “pretty journal” — loses the **spy-bird + control tower** positioning unless copy and **motion** (scope reticle, not glass rows) carry the story.

### 4. Maintenance surface

**Mechanism:** Two OFL families (Plex + Fraunces) + light/dark paper tokens + optional textures = **3×** the `Theme` regression matrix (`TokenCoverageTests`, font registration tests, AX5 UI tests).

**Failure:** Every future feature ships **slower** because designers must ask “does this sheet get paper or system chrome?”

---

## What would change the doubt calculus

- **Proof:** Paper only on **Login + empty states**; lists stay **flat system list** with Fraunces **nav title only** — keeps stylization without touching scroll perf.
- **Proof:** One **high-contrast “ATC”** toggle that strips texture and bumps mono size — maps to existing accessibility discipline.

---

## Verdict

**Proceed with Paper-zine only under a scoped “surface budget”** (login, nav chrome, chips — not per-row decoration). If that scope feels too timid, **Cinematic** may ship faster with fewer AX edge cases; if you want maximum differentiation, **Brutalist** wins memorability but loses legibility unless heavily gated.
