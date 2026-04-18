---
title: "Systematic cross-repo backport workflow for diverged forks"
date: 2026-04-18
category: best-practices
module: development-workflow
problem_type: best_practice
component: development_workflow
severity: medium
applies_when:
  - A fork has diverged significantly (20+ commits) from upstream
  - You need to selectively backport functional improvements while excluding design/theme changes
  - Two codebases share architecture but have divergent design systems or branding
resolution_type: workflow_improvement
tags:
  - git
  - backport
  - fork
  - cherry-pick
  - cross-repo
  - theme-adaptation
  - audit
---

# Systematic cross-repo backport workflow for diverged forks

## Context

DOOMBTS was forked from DOSBTS (a CGM app). After independent development, DOOMBTS accumulated 67 commits with functional improvements (bug fixes, new chart features, UX enhancements) interleaved with design-only commits that changed the visual theme (DoomTheme). The task was to backport the functional value without importing any design changes. A naive merge would produce 40+ conflicts, mostly in color token files, and risk design leakage into DOSBTS's amber CGA aesthetic.

## Guidance

Follow this five-step workflow for selective cross-repo backporting:

### Step 1: Find the fork point

```bash
# Add upstream remote if missing
git remote add upstream <source-repo-url>
git fetch upstream

# Find the exact divergence SHA
git merge-base HEAD upstream/main
```

### Step 2: Enumerate divergent commits

```bash
git log --oneline <merge-base-sha>..HEAD
```

Count them. This sets your scope before you do any work.

### Step 3: Categorize every commit

For each commit, run `git show <sha> --stat` and classify:

- **PORT** — functional logic, bug fixes, features. Files are in business logic, view models, or theme-agnostic UI. Commit subjects: `feat:`, `fix:`, `refactor:`.
- **SKIP** — design/theme only. Files exclusively in `DesignSystem/`, `Assets/`, or the commit has `style:` prefix.
- **EVALUATE** — mixed functional + design (e.g., new view file with hard-coded theme tokens). Needs manual inspection and token substitution.

Document your audit as a structured plan: commit SHA, files, bucket, complexity (trivial/low/medium), dependencies, conflict notes. Do this before writing any code.

### Step 4: Execute by complexity tier

Process PORT and EVALUATE commits in ascending complexity:

- **Trivial** (1-line or single-file, no theme coupling): direct edit on a feature branch.
- **Small** (1-5 files, some theme coupling): manual copy with token substitution.
- **Large** (new view files, new middleware, new state): full brainstorm → plan → implement → review pipeline in the target repo.

### Step 5: Theme token adaptation

Establish a token mapping table before starting:

| Source token | Target token |
|---|---|
| `DoomTheme.*` | `AmberTheme.*` |
| `DoomTypography.*` | `DOSTypography.*` |
| `DoomSpacing.*` | `DOSSpacing.*` |

Always map to the target design system's named tokens. Never copy raw hex values.

## Why This Matters

**Without this workflow:** You either waste hours adapting design-specific code with zero functional value, or accidentally merge theme changes that break the target app's visual identity. Both outcomes are common without an explicit audit step.

**With this workflow:** You process only the ~10% of commits that carry functional value, skip the ~90% that are design-only, and have a written record of every decision. The audit also surfaces hidden dependencies between commits before you start porting.

**Merge vs cherry-pick:** A full merge across a heavily diverged fork with design-system changes produces conflicts in nearly every file. Selective cherry-pick or manual adaptation is almost always cleaner.

## When to Apply

- A fork has accumulated 20+ commits of independent development
- Two repos share architecture but differ in design system, theme, or branding
- You need a defensible audit trail of what was ported and why
- The source repo used conventional commit prefixes (`style:`, `feat:`, `fix:`), making classification faster

Does NOT apply when:
- The fork has fewer than a handful of commits — just cherry-pick manually
- The repos have diverged architecturally (different state management, data models) — adaptation cost outweighs porting value

## Examples

**Classification — SKIP:**
```
commit 7f3a91b  style(theme): switch chart grid to DoomTheme.gridLine
 App/DesignSystem/DoomTheme.swift             | 3 +++
 App/Views/Overview/ChartView.swift           | 2 +-
```
Only `DoomTheme.swift` and a 2-line color reference. No functional delta. SKIP.

**Classification — PORT:**
```
commit 8153b15  fix(ui): Y-axis trailing, sound overlap guard
 App/Modules/ConnectionNotification.swift     | 13 ++++---
 App/Views/Overview/ChartView.swift           |  2 +-
```
Bug fix (Y-axis visibility) + reliability fix (audio overlap guard). PORT — trivial complexity.

**Classification — EVALUATE:**
```
commit 4a5a5be  feat(chart): Libre-style marker lane above chart
 App/Views/Overview/EventMarkerLaneView.swift | 159 +++++++++++++++++
 App/Views/Overview/ChartView.swift           | 280 ++++++++++++------
```
New view file with hard-coded `DoomTheme` references throughout. EVALUATE → full plan pipeline with token substitution.

**Session results:** From 67 DOOMBTS commits: 5 classified PORT/EVALUATE, 62 classified SKIP. 3 trivial backports shipped in <30 minutes. 1 large backport (event marker lane, 376 lines) shipped through the full pipeline. Zero design-system leakage.

## Related

- `docs/plans/2026-04-18-002-chore-doombts-backport-audit-plan.md` — the master audit plan from this session
- `docs/plans/2026-04-18-003-feat-event-marker-lane-plan.md` — implementation plan for the large backport
- `docs/brainstorms/2026-04-18-event-marker-lane-requirements.md` — requirements for the marker lane
- Linear issues: DMNC-635, DMNC-714, DMNC-715
