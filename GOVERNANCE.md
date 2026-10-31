# Governance

BetterCrest is a fork of Crest maintained by
[devops-senpai](https://github.com/devops-senpai). This document explains who
makes decisions now and how that can grow.

## Maintainer

devops-senpai is the current maintainer and release owner. The maintainer is
responsible for product direction, review and merge decisions, security
coordination, Apple-platform signing, and BetterCrest releases.

Source code contributions are accepted under the repository's MPL-2.0 license.
The Crest name and visual identity belong to Paul Davis and are governed by
[TRADEMARKS.md](TRADEMARKS.md); BetterCrest is not affiliated with or endorsed
by Crest or Paul Davis.

## How decisions are made

- Reproducible work is tracked in
  [GitHub Issues](https://github.com/devops-senpai/BetterCrest/issues).
- _Placeholder: BetterCrest has no public discussion forum, project board or
  release milestones yet._
- Upstream Crest's `main` is merged regularly (`Scripts/sync-upstream.sh`).
  When upstream and BetterCrest solve the same problem differently, upstream's
  solution is preferred unless there is a stated reason to diverge.
- Architecture decisions preserve Space isolation, live page identity,
  native Apple-platform behavior, security boundaries, and sustainable
  maintenance.
- The maintainer makes the final call when platform constraints, security,
  project coherence, or release responsibility require one accountable owner.

Sponsorship never determines issue priority or acceptance.

## Becoming a maintainer

Maintainer access is earned through sustained, trustworthy participation:
high-quality contributions, useful review, respectful community work, and
demonstrated care for the architecture and release boundaries. Access grows
gradually from contribution and triage to review and, when appropriate, merge
or release responsibilities.

The project may adopt a more formal voting or multi-maintainer model when its
active maintainer group is large enough for that process to solve a real
coordination problem.
