---
title: "chore: Audit DOOMBTS changes for backport to DOSBTS"
type: refactor
status: active
date: 2026-04-18
---

# chore: Audit DOOMBTS changes for backport to DOSBTS

## Overview

DOOMBTS was forked from DOSBTS at commit `c2f062d0` (after the treatment workflow shipped). Since then, DOOMBTS has accumulated ~67 commits with 4156 insertions across 168 files. Most changes are design/theme work (Doom reskin), but several contain functional improvements worth porting back.

## Problem Frame

DOOMBTS and DOSBTS share the same glucose monitoring core but have diverged. Functional improvements (bug fixes, new features, UX patterns) made in DOOMBTS are not available in DOSBTS. Without a systematic audit, useful work will be lost or duplicated.

## Scope Boundaries

- **In scope:** Functional features, bug fixes, architectural improvements
- **Out of scope:** Doom theme (DoomTheme, DoomTypography, DoomSpacing, Doom face sprites, Doom sounds, Doom fonts, weapon selector navigation, HUD digits)
- **Out of scope:** iOS 26 deployment target bump (DOSBTS targets iOS 15)

### Deferred to Separate Tasks

- Actual backport PRs (one per portworthy change)

## DOOMBTS Change Audit

Fork point: `c2f062d0` (2026-04-15, after treatment workflow merge)
DOOMBTS commits since fork: 67

### Category: PORT (functional improvements worth backporting)

#### 1. Libre-style marker lane above glucose chart (DMNC-709)

**Commit:** `4a5a5be0`
**Files:** `ChartView.swift` (280 lines changed), `EventMarkerLaneView.swift` (159 lines, new)
**What:** Replaces overlapping meal/insulin/exercise annotations with a dedicated marker lane above the chart. Icons per type, zoom-dependent consolidation, tap-to-expand for grouped markers.
**Port complexity:** Medium — the view is self-contained (`EventMarkerLaneView`) but `ChartView` modifications will conflict with DOSBTS's recent meal impact overlay work. Needs theme token adaptation (DoomTheme -> AmberTheme).
**Dependencies:** None
**Note:** This directly relates to DMNC-635 (Move logged inputs above chart). May supersede or inform that backlog item.

#### 2. Connection sound overlap guard

**Commit:** `8153b153` (mixed with design fixes)
**Files:** `ConnectionNotification.swift` (~13 lines)
**What:** Guards against overlapping audio playback when connection state fires rapidly during sensor pairing.
**Port complexity:** Low — small isolated fix in one file.
**Dependencies:** None

#### 3. Event sounds for connection/glucose transitions (pattern only)

**Commit:** `6d75a838`
**Files:** `ConnectionNotification.swift` (~11 lines)
**What:** Haptic feedback on sensor connect/disconnect and back-in-range transitions. The Doom-specific sounds are not portable, but the haptic + event trigger pattern is.
**Port complexity:** Low — extract the haptic feedback additions, skip the Doom sound references.
**Dependencies:** None

#### 4. Y-axis placement fix (trailing instead of leading)

**Commit:** `8153b153` (mixed with design fixes)
**Files:** `ChartView.swift` (~2 lines)
**What:** Moves chart Y-axis from `.leading` to `.trailing` so it's always visible (chart auto-scrolls to trailing edge).
**Port complexity:** Trivial — one-line change.
**Dependencies:** None

#### 5. Heart rate legend placement in chart header

**Commit:** `6925133c`
**Files:** `ChartView.swift`
**What:** Moves HR legend from below chart to header row for better space usage.
**Port complexity:** Low — isolated UI change.
**Dependencies:** None

### Category: EVALUATE (mixed functional + design, needs cherry-pick)

#### 6. Exercise logging UI (AddExerciseView)

**Commits:** `7af2a1b7` (added), `70fa65c5` (removed), `602a7e92` (documented decision)
**What:** AddExerciseView was added then removed — the decision was that exercise data comes from HealthKit only, so manual entry is unnecessary. The view exists but is dead code.
**Port decision:** Skip — DOSBTS already imports exercise from HealthKit. The view was intentionally removed. However, if DOSBTS ever wants manual exercise entry, `AddExerciseView.swift` from commit `7af2a1b7` is a ready template.

#### 7. Streak counter and difficulty rating

**Commit:** `ac086112`
**Files:** `StreakCounterView.swift`, `DifficultyRatingView.swift`, `GameMechanicsMiddleware.swift`
**What:** Game mechanic features — streak tracking for consecutive in-range days, daily difficulty rating. These are functional features but deeply tied to the Doom game theme.
**Port decision:** Evaluate — the streak concept is useful for any CGM app but the implementation uses Doom-specific state (`doomDifficulty`, `streakDays`). Would need significant adaptation to fit DOSBTS's amber CGA aesthetic.

#### 8. Merge ALERTS into CONFIG settings

**Commit:** `64c9de61`
**What:** Consolidated the separate Alerts view into the Config/Settings view.
**Port decision:** Evaluate — DOSBTS has a separate `AlertsView.swift`. May or may not be a better UX to merge them.

### Category: SKIP (design/theme only)

- `859c33a1..f77abde0` — Doom design system (DoomTheme, DoomTypography, DoomSpacing)
- `5392dee2` — Doom game-mechanic state properties
- `004df7cf` — Doom weapon selector navigation
- `d4f028a3..b09f04e9` — DoomguyFace middleware and sprites
- `29bafc1b` — Mass theme swap (AmberTheme -> DoomTheme)
- `0260d38f` — Side panel navigation (Doom-specific)
- All `style:` commits — Font changes, Doom styling across views
- `e166f366..7dc09892` — DOOMBTS rebranding (bundle ID, display name, project rename)
- `5a75ffd3` — iOS 26 deployment target bump (DOSBTS targets iOS 15)
- `bf227b94` — Doomguy app icon, Doom sound defaults
- `e839ad45` — Doom-themed treatment workflow text
- `4478bae8` — Doom widget reskin
- `133317ca` — Doom Live Activity reskin
- All build number bumps, devjournal entries, docs-only changes

## Recommended Backport Order

1. **Y-axis trailing fix** — trivial, improves chart readability
2. **Connection sound overlap guard** — small bug fix, prevents audio issues
3. **HR legend placement** — small UX improvement
4. **Haptic feedback on connect/disconnect** — good UX, small change
5. **Marker lane (DMNC-709)** — largest change, most impactful, but conflicts with meal impact overlay. Plan carefully with DMNC-635.

## Implementation Units

- [ ] **Unit 1: Create individual backport issues**

**Goal:** Create one Linear issue per portworthy change with cherry-pick instructions and conflict notes.

**Approach:**
- Items 1-4 from the PORT category each get their own issue
- Item 5 (marker lane) gets a larger issue, possibly linked to DMNC-635
- Include the source commit SHA, affected files, and expected conflicts in each issue description

- [ ] **Unit 2: Execute trivial backports (items 2, 3, 4)**

**Goal:** Cherry-pick or manually apply the three small fixes that have no conflicts.

**Dependencies:** Unit 1 (issues created for tracking)

- [ ] **Unit 3: Plan marker lane integration with meal impact overlay**

**Goal:** Determine how DMNC-709 (marker lane) and the meal impact overlay (DMNC-688) coexist. Both modify ChartView significantly.

**Dependencies:** DMNC-688 merged

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Marker lane conflicts with meal impact overlay | Plan Unit 3 carefully — both modify ChartView's meal marker rendering |
| Cherry-picked code references DoomTheme tokens | Search-and-replace DoomTheme -> AmberTheme, DoomTypography -> DOSTypography |
| DOOMBTS targets iOS 26, DOSBTS targets iOS 15 | Any backported code using iOS 16+ APIs needs `@available` guards |

## Sources & References

- DOOMBTS repo: `/Users/doke/extracode/DOOMBTS`
- Fork point: `c2f062d0` (2026-04-15)
- Related issue: DMNC-635 (Move logged inputs above chart)
- Related PR: CinimoDY/DOSBTS#14 (Meal impact overlay — affects marker lane integration)
