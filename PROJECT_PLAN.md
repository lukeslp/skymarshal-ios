# Project plan — Skymarshal iOS

Living snapshot of objectives and boundaries. Product copy and build commands stay in [`README.md`](README.md); contributor rules in [`AGENTS.md`](AGENTS.md).

## Current milestone

- **Distribution:** Pre–public TestFlight; public link pending Beta App Review ([`README.md` Status](README.md)).
- **Quality bar:** Full `xcodebuild test` green before release-worthy changes; preserve 429 backoff and deletion URI semantics ([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).

## Roadmap tranche (native imports from upstream CLI/web patterns)

Shipped in-repo: on-device **Insights** analytics, **saved search presets**, **content sort**, **cleanup presets**, **dry-run unfollow**, **profile explorer** (followers/following lists). Toggle keys live in [`FeatureFlags`](ios/SkymarshalCore/Standards/FeatureFlags.swift).

## Merge and review discipline (large tranches)

- Canonical facts + decision question for council review: [`docs/REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md`](docs/REVIEW_BRIEF_IOS_ROADMAP_BRANCH.md).
- Synthesized `/team` + `/consensus` outcomes, Option A vs B, and pre-merge gates: [`docs/TEAM_CONSENSUS_DECISION_PACKAGE.md`](docs/TEAM_CONSENSUS_DECISION_PACKAGE.md).
- SwiftUI contributor checklist (Theme, motion, menus, known dry-run scope): [`docs/CONTRIBUTOR_UX.md`](docs/CONTRIBUTOR_UX.md).

## Near-term polish (non-blocking)

- Row min-height polish for dense bio + badge rows (56–60pt) noted in workspace guidance.
- Keep README test counts / build numbers aligned with CI or manual verification after substantive changes.

## Explicit non-goals (unless requested)

- Firehose, network graphs, hosted analytics backends.
- CAR archive decode on device (API pagination only).
- Third-party AT Protocol SDKs; dependency-free `URLSession` remains the rule.
- Marketing copy using “AI” framing ([`app-store/`](app-store/) and in-app voice).

## Technical anchors

- Orchestration: [`ios/SkymarshalCore/Services/ContentService.swift`](ios/SkymarshalCore/Services/ContentService.swift).
- Behavioral parity with Python reference: [`MIGRATION.md`](MIGRATION.md), [`reference/README.md`](reference/README.md).
- Full upstream vs iOS scope map (not a port backlog): [`docs/UPSTREAM_FEATURE_GAP.md`](docs/UPSTREAM_FEATURE_GAP.md).
