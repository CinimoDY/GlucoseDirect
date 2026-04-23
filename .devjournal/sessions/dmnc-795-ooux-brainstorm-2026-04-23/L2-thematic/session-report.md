# Session Report — DMNC-795 OOUX Brainstorm

**Date:** 2026-04-23
**Branch:** main (no commits; spec + session artifacts only)
**Duration:** One brainstorming session, design-only scope

## What Was Done

**Brainstormed the OOUX pass for DOSBTS** (DMNC-795, High). Worked through six clarifying questions with the user — each question was one decision, chosen from 2–4 candidate options presented with tradeoff notes and a visual (where applicable). Visual companion used throughout for Pattern 2 interaction-model candidates, insulin input-control candidates, and Meal pattern-mapping candidates.

**Locked in seven scope decisions** (captured in `decisions.md`). The most consequential:

- Scope B — **design-only spec**, no implementation or migration in this pass. Component implementation and per-view migrations become three follow-up Linear issues.
- Pattern 1 (StagingPlate) kept narrow — multi-item batch review only. Not a generic editable-pre-commit surface.
- Pattern 2 (CategoryPanel) refined from the issue's original sketch: segmented category-toggle chip row + inline attribute panel, no preset-dose drill-down. Native input controls below the selected category.
- Insulin input controls = stepper + quick-time chips (zero keyboard for ~90% of entries, matches Apple Health / Streaks / Oura idioms).
- Meal mapping = Pattern 1 + favourite shortcut. Favourite tap keeps today's 1-tap direct-log speed. Long-press → StagingPlate for edit.

**Produced an object map** — 3 entry objects, 8 read/monitoring objects, every relationship grep-verifiable against Swift types. SVG staged in `L2-thematic/object-map.svg`.

**Drafted the spec** at `docs/brainstorms/2026-04-23-ooux-catalog-and-entry-patterns-requirements.md`. Self-reviewed inline for placeholders, consistency, scope, ambiguity. Two ambiguities fixed before the spec file landed:

- Favourite 1-tap explicitly labelled *preserves today's behaviour* (not a new design decision).
- `AddMealView` disposition clarified — stays as the edit-existing-entry view; its role as a standalone new-entry surface goes away.

## Commits (main)

None — design-only session. No code changed.

## Issues Updated

- **DMNC-795** — comment added with link to the spec + enumeration of the three follow-up issues this unblocks. Marked for status update when follow-ups are filed.

## Follow-up Issues to File

Three follow-up issues derived from the spec's § Out-of-scope:

1. *feat: implement StagingPlate + CategoryPanel shared components (DMNC-795 follow-up)*
2. *refactor: migrate AddInsulinView to CategoryPanel* (blocked by #1)
3. *refactor: route all Meal entry paths through StagingPlate + favourite long-press* (blocked by #1)

## Next Steps

1. Pick up the first follow-up (components implementation) — start with `writing-plans` to produce an implementation plan.
2. DMNC-791 (Figma library) can now reference this catalog for its own planning.
3. No TestFlight build needed — no code changed.

## Documentation Status

- **`docs/brainstorms/`:** +1 new file — `2026-04-23-ooux-catalog-and-entry-patterns-requirements.md`. Matches existing `YYYY-MM-DD-<topic>-requirements.md` convention in that directory.
- **CLAUDE.md:** no changes needed this session. The Pattern 1 / Pattern 2 vocabulary lands in code when the components exist, at which point CLAUDE.md should get a "Shared entry-interaction patterns" note.
- **CHANGELOG.md:** no changes (design-only, not user-visible).
- **`docs/solutions/`:** no new compound learning this session — follow-ups will likely generate one after component implementation lands.

## Open PRs

None.

## Build / TestFlight

No build. Build 62 is the current TestFlight release from 2026-04-22.

## Session Artifacts

- `L2-thematic/object-map.svg` — standalone SVG extracted from the brainstorm companion (note: map labels show the pre-review draft's Pattern names; see the spec for the revised approach)
- `L2-thematic/decisions.md` — scope-decisions table + catalog content
- `L2-thematic/themes.md` — retrieval tags
- `L3-raw/` — original brainstorm HTML screens (pattern2-semantics, pattern2-v2, insulin-input-controls, meal-mapping, object-map) served live via the visual companion during the session
- Plan file (pre-exit): `/Users/doke/.claude/plans/what-should-we-work-mossy-widget.md` (reference only; canonical content moved into `decisions.md` + the spec)

## Post-review revision (same day)

After the initial commit, a 6-persona document review (coherence, feasibility, product-lens, design-lens, scope-guardian, adversarial) surfaced consensus findings that triggered a substantial revision:

- **`CategoryPanel` wrapper dropped** — three reviewers identified it as renaming plain SwiftUI idioms (`Picker(.segmented)` + `switch`) with one consumer. Spec now commits only to primitives: `StepperField`, `QuickTimeChips`, `AmberChip`.
- **`StagingPlate` downgraded to provisional** — five concerns tangled with generic staging in the 882-LOC `FoodPhotoAnalysisView` mean the reusable API cannot be responsibly designed before the first in-place refactor. DMNC-800 does the refactor; extraction is a stretch goal.
- **Favourite long-press dropped** — hidden-affordance risk in a medical app, no user evidence cited. Post-log edit via chart-marker tap remains the supported path.
- **Premise reframed** — from "interactions feel inconsistent (user pain)" to "maintenance surface on 882-LOC God View + forward-looking code reuse (author pain, honestly)."
- **Missing interaction states added** — category-switch field retention, `QuickTimeChips` NOW semantics, chip visual treatment.
- **Success criterion #5 revised** — allows both typed references and documented UUID/factory conventions; Meal↔PersonalFood and Meal↔FavoriteFood are correctly the latter.
- **All three follow-up Linear issues (DMNC-798/799/800) rescoped** to match.

The revision is not a re-brainstorm — it's the outcome of a single review pass where consensus was clear enough that the remediation was mechanical. See the Linear comment on DMNC-795 for the full summary.
