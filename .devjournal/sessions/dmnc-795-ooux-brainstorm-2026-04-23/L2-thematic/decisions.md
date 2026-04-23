# Scope Decisions — DMNC-795 OOUX Brainstorm

Captured during the 2026-04-23 session. Each row = a decision the user validated against 2–4 explicit alternatives with rationale notes.

| # | Decision | Alternatives considered | Rationale |
|---|---|---|---|
| 1 | **Scope B — design-only spec** | A: everything end-to-end incl. AddInsulinView migration. C: pattern-first, catalog-lite. | Keeps the API surfaces reviewable before any refactor lands. Matches user's "sweep > piecemeal" preference for the eventual migrations — one sweep later is cleaner than half-migrating now. |
| 2 | **Two-tier catalog (entry full, read/monitoring one-liner + relationships)** | A: full OOUX for all 11 nouns. C: entry-objects only. | Depth lives where the patterns need it. Reads' relationships into entries feed DMNC-791 (Figma library) downstream. |
| 3 | **Entry objects = Meal, InsulinDelivery, BloodGlucose** (Exercise = HK-imported; Calibration = out-of-scope) | A: all five incl. Exercise + Calibration. B: four (drop Calibration). | User correction: Exercise comes from HealthKit → read/monitoring tier, not an entry object. Calibration is a specialised regression-math flow; neither pattern benefits it. |
| 4 | **Pattern 1 (StagingPlate) = multi-item batch review only** | B: staging plate = any pre-commit editable surface. C: staging plate = `List<Pattern2Panel>`. | Keeps the name semantically narrow (matches how `FoodPhotoAnalysisView` uses it today). Pattern 2 is its own distinct inline-entry pattern, not a special case of Pattern 1. |
| 5 | **Pattern 2 (CategoryPanel) = segmented category toggle + inline attribute panel** (no preset-dose drill-down) | A: original two-stage drill-down with preset chips. C: chip → modal sheet. | User refinement: category row acts like a segmented toggle, and the input appears directly below — no "selected chip stays visible," no preset grid. Native input controls for values. |
| 6 | **Insulin input controls = stepper + quick-time chips** | I: TextField + DatePicker.compact (current, polished). III: Wheel pickers (DOS-aesthetic). | Zero keyboard for ~90% of entries. Matches Apple Health / Streaks / Oura idioms. Stays in-context (no keyboard popup), uses the same chip vocabulary as the category row. |
| 7 | **Meal mapping = Pattern 1 + favourite shortcut** | A: Pattern 1 always (no favourite shortcut). B: Pattern 2 as entry-method switch. | Preserves today's 1-tap-favourite speed (by design — favourites already passed review when created). Long-press is the explicit escape hatch for edit-before-log. Two commit paths for one object is a designed exception, not an accident. |

## Reference: object catalog (final)

*The canonical catalog lives in the spec at `docs/brainstorms/2026-04-23-ooux-catalog-and-entry-patterns-requirements.md` § Object catalog.* This file only captures the scope-decisions process.

## Reference: object map

See `object-map.svg` in this directory for the rendered graph. ASCII fallback also in the spec.
