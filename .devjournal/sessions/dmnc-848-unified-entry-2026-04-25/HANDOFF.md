# DMNC-848 — Session Handoff

**Date:** 2026-04-25
**Branch:** `main` (no worktree)
**Status:** Plans approved, doc-reviewed, revised v2. Phase 0 prep started — Task 0a done.

---

## TL;DR for the next session

Three plans + spec are ready. Execute Core first (subagent-driven), then HR, then strict-separation, then deploy to TestFlight. Phase 0 Task 0a is already done; resume from Task 0b.

### How to resume (pick one)

**Option A — User-invoked (recommended).** In a fresh Claude Code session, type at the prompt:

```
/skill superpowers:subagent-driven-development Execute docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md from Task 0b onward. Phase 0 Task 0a (CaseIterable + shortLabel on InsulinType) is already merged at commit 0f13f9ee. v2 plan — all doc-review blockers already fixed. After Core lands, run CE review + fixes + merge, then repeat for HR and strict-separation plans in the same directory, then deploy to TestFlight per CLAUDE.md.
```

**Option B — Assistant-invoked equivalent** (paste this as your first user message in a fresh session):

```
Please continue the DMNC-848 implementation. Read .devjournal/sessions/dmnc-848-unified-entry-2026-04-25/HANDOFF.md for context, then invoke the superpowers:subagent-driven-development skill on docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md starting from Task 0b.
```

**Option C — Batched execution (faster, less rigor).** If subagent dispatch becomes unreliable again, fall back to:

```
/skill superpowers:executing-plans docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md — resume from Task 0b. Task 0a committed as 0f13f9ee.
```

The `executing-plans` skill batch-executes with user checkpoints rather than per-task subagent dispatch, so it works even when the controller session is heavy.

### Minimal invocation (one-liner)

```
/skill superpowers:subagent-driven-development Execute Core plan, resume from Task 0b. See .devjournal/sessions/dmnc-848-unified-entry-2026-04-25/HANDOFF.md.
```

---

## What's done

### Brainstorm + spec
- Brainstorm session: `.superpowers/brainstorm/35252-1777068283/content/`
- Companion screenshots: `.devjournal/sessions/dmnc-848-unified-entry-2026-04-25/L2-thematic/screens/` (24 PNGs, screens 04–24)
- Spec: `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` (committed `7e3c9846`)

### Plans (v2, post doc-review)
- Core: `docs/superpowers/plans/2026-04-25-dmnc-848-core-unified-entry-plan.md` — 14 tasks, 10 phases (D1, D2, D3, D4, D5, D8)
- HR: `docs/superpowers/plans/2026-04-25-dmnc-848-hr-overlay-plan.md` — 4 tasks (D6) **reframed as gate-existing-feature** because HR `LineMark` already ships at `ChartView.swift:699-710`
- Strict-separation: `docs/superpowers/plans/2026-04-25-dmnc-848-strict-separation-plan.md` — 5 tasks (D7), **dropped IOB-sandwich rule** because IOB is in the glucose `Chart {}` canvas, not a separate lane
- Plans v1 commit: `d8998961`. v2 (revisions) commit: `684b383c`.

### Doc review findings folded into v2 plans
**Core plan v2 fixes (12 compile-blockers + 8 design issues):**
- Use id-preserving constructors instead of mutating `let` fields on `MealEntry`/`InsulinDelivery`
- Add `CaseIterable` to `InsulinType` (Phase 0 Task 0a — DONE)
- Real `ExerciseEntry` field names: `startTime` (not `startDate`), `activityType` (not `workoutType`)
- Real DataStore API: `MealStore.swift` (not `MealEntryStore.swift`); middleware dispatches `.loadMealEntryValues` after writes (not phantom `fetchMealEntries()`)
- Adapt existing `EventMarkerLaneView` (171 LOC, file at `App/Views/Overview/EventMarkerLaneView.swift`); do not create parallel `MarkerLaneView`
- Reuse zoom-aware `updateMarkerGroups()` already in ChartView; do not invent fixed-15-min `groupAll`
- Closure callback for marker tap (drop `setSelectedEntryGroup` Redux action)
- Drop ChartView's `.sheet(item: $tappedMealEntry)` and `.sheet(item: $tappedMealGroup)` to avoid sibling-sheet collisions
- Hoist `EditableFoodItem` from `FoodPhotoAnalysisView.swift:12` to `Library/Content/EditableFoodItem.swift`
- Restore IN PROGRESS / confounders / PersonalFood avg / mmol/L formatting in row sub-line
- Wrap combined modal in `ScrollView` for Dynamic Type ≥ xxxLarge / iPhone SE
- Single Phase 0 Task 0c registers all 9 new test files in `project.pbxproj` (CLAUDE.md: tests not auto-synced)
- Reducer is no-op for update actions; rely on middleware load-after-write pattern (avoids race)
- Reducer test API: free function `directReducer(state:action:)` and `AppState()` no-arg init

**HR plan v2:**
- HR `LineMark` already exists; `cgaMagenta` already in `AmberTheme:43`
- Toggle home is `App/Views/Settings/AppleExportSettingsView.swift` (`HealthKitSettingsView.swift` doesn't exist)
- Reuse existing unit-aware scaling formula (don't hardcode 40...300)
- Default off per brainstorm — flagged as user-visible regression in CHANGELOG (HR was always-on for build ≤ 62)

**Strict-separation plan v2:**
- IOB-sandwich rule dropped (IOB is `AreaMark` inside the glucose `Chart {}`, not a separate lane)
- Default `.top` (matches today's placement, no regression)
- Inline picker in `AdditionalSettingsView` (no new `ChartSettingsView` file)

### Phase 0 prep started
- ✅ **Task 0a — `InsulinType: CaseIterable` + `shortLabel` extension** — commit `0f13f9ee`. Build verified.

---

## What's next (in order)

### Core plan execution

Resume from **Task 0b**. Phase 0 remaining: 0b (hoist `EditableFoodItem`), 0c (register 9 test files in pbxproj — note: this is the most fiddly one, will likely need careful UUID generation), 0d (promote `EventMarker` types out of ChartView).

Then Phases 1 → 10 in order. Don't reorder — Phase 0 is depended on by everything else.

**Critical correctness reminders for Core (do not deviate):**

- **Task 5** (FoodPhotoAnalysisView migration): preserve the existing `NavigationLink → ItemBarcodeScannerView` flow with the `isItemScanActive` guard. The plan's Step 1 shows the wrap pattern — implement it, don't simplify.
- **Task 7 + 8** (Redux update actions): reducer is a **no-op** for `updateMealEntry`/`updateInsulinDelivery`. Middleware persists via `try value.update(db)` then dispatches `.loadMealEntryValues` / `.loadInsulinDeliveryValues`. The standard load round-trip then refreshes the in-memory array. Do not mutate the array in the reducer.
- **Task 9** (AddInsulinView rewrite): preserve the existing `addCallback: (Date, Date, Double, InsulinType) -> Void` and `currentIOB: Double?` parameters. Add new optional `editingDelivery: InsulinDelivery? = nil`. Update OverviewView's call site to pass `editingDelivery: nil`.
- **Task 12** (CombinedEntryEditView): use **id-preserving constructors** for both update dispatches:
  ```swift
  let updated = MealEntry(
      id: original.id,
      timestamp: time,
      mealDescription: ...,
      carbsGrams: ...,
      analysisSessionId: original.analysisSessionId,
      proteinGrams: original.proteinGrams,
      fatGrams: original.fatGrams,
      calories: original.calories,
      fiberGrams: original.fiberGrams
  )
  ```
  Same for `InsulinDelivery`. **Never mutate `let` fields.** No auto-create from empty companion sections (modal is edit-only).
- **Task 13** (ChartView integration): MUST drop `.sheet(item: $tappedMealEntry)` (~lines 198-214), `.sheet(item: $tappedMealGroup)` (~lines 227-286), `.confirmationDialog` for `tappedInsulinEntry` (~line 215), and `activeMealOverlay` inline card (~lines 575-680). Delete the `@State` properties for those. Use a closure callback `onTapMarkerGroup: (ConsolidatedMarkerGroup) -> Void` from OverviewView, NOT a Redux round-trip.

### After Core lands
1. Open Core PR.
2. CE code-review: `Skill("compound-engineering:review", "...")`. Apply ALL findings including minor/advisory (per durable feedback rule in `~/.claude/projects/.../memory/feedback_apply_all_review_fixes.md`).
3. Re-run review until clean.
4. Merge.

### Then HR plan
Same flow: subagent-driven execute → CE review → fix all → merge.

### Then strict-separation plan
Same flow. Note: depends on Core's `EventMarkerLaneView` adaptation having landed.

### Then TestFlight
Per CLAUDE.md "deploy to TestFlight" section:
1. Bump `CURRENT_PROJECT_VERSION` (4 occurrences in `project.pbxproj`).
2. Promote `[Unreleased]` → `[Build N] — YYYY-MM-DD` in `CHANGELOG.md`. Add empty `[Unreleased]` above.
3. `./deploy.sh`.

---

## Gotchas the next session should know

1. **Working on `main`, not a worktree.** This deviates from the brainstorming skill's recommendation but matches the user's explicit instruction earlier in the session. Each task makes its own commit.

2. **`InsulinType.allCases` is now available** (Task 0a done). Use it freely in chip-row code.

3. **iOS 26 deployment target.** No `if #available` guards; new `onChange(of:_:)` two-arg form mandatory.

4. **CHANGELOG split-cycle rule:** if a Core feature merges before the version bump but ships only after the next bump, move its CHANGELOG entry to the correct `[Build N]` at promotion time. Same for HR + strict-separation.

5. **Test files NOT auto-synced.** Phase 0 Task 0c is mandatory before any new test file's `@Test` will actually run. UUIDs in pbxproj must be unique 24-char hex (use `uuidgen | tr -d '-' | cut -c 1-24`). Don't skip this.

6. **`fileSystemSynchronized` for Swift sources.** New `.swift` files under `App/`, `Library/`, `Widgets/` auto-pick up — only tests need manual pbxproj edits.

7. **Reducer runs BEFORE middlewares** (per CLAUDE.md). Don't write reducer logic that depends on middleware effects of the same action.

8. **No nested sheets** (per CLAUDE.md). The Edit handoff in Task 13 uses `pendingSheet`/`onDismiss` sequential swap, NOT a nested presentation.

9. **GRDB deadlock pattern** (per CLAUDE.md): never write inside `asyncRead`. The update middleware in Tasks 7/8 uses synchronous `dbQueue.write { try value.update(db) }` — fine, no `asyncRead` involved.

10. **Memory rule (durable):** at code-review time, apply EVERY finding including advisory/P3. Don't filter by severity unless asked.

---

## Open questions for the user

None at the moment. The brainstorm + spec + plans are all locked. If during execution a subagent surfaces a question, escalate per the subagent-driven-development skill's BLOCKED protocol.

---

## Session artifacts saved

- Spec: `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md`
- Plans: `docs/superpowers/plans/2026-04-25-dmnc-848-{core-unified-entry,hr-overlay,strict-separation}-plan.md`
- Brainstorm HTML mockups: `.superpowers/brainstorm/35252-1777068283/content/`
- Screenshots: `.devjournal/sessions/dmnc-848-unified-entry-2026-04-25/L2-thematic/screens/`
- This handoff: `.devjournal/sessions/dmnc-848-unified-entry-2026-04-25/HANDOFF.md`

---

## Tasks (for resumption tracking)

The current Claude Code task list (TaskList tool) reflects this state:

- #67 [in_progress] Execute Core plan via subagent-driven-development
- #68 [pending] CE code-review Core PR + fix all findings
- #69 [pending] Merge Core PR
- #70 [pending] Execute HR plan + review + fix + merge
- #71 [pending] Execute strict-separation plan + review + fix + merge
- #72 [pending] Bump build + promote CHANGELOG + deploy to TestFlight

Other completed tasks (brainstorm phases, doc reviews, plan revisions) are already marked done.

---

**End of handoff. Good luck.**
