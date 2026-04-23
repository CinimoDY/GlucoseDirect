# OOUX Catalog + Entry Patterns

**Issue:** [DMNC-795](https://linear.app/lizomorf/issue/DMNC-795) (High)
**Scope:** Design-only. Defines object catalog + shared primitives for single-object entry + per-feature mapping. Component implementation and view migrations are tracked in follow-up Linear issues (DMNC-798, DMNC-799, DMNC-800).
**Unblocks:** DMNC-791 (Figma library decision), DMNC-797 (micro-interactions polish).
**Related (not strictly unblocked):** DMNC-796 (unified entry interactions) — see § Pattern 1 open questions; DMNC-796 is where tap-vs-long-press semantics are properly owned.

**Revision history:** First draft 2026-04-23; revised same day after a 6-persona document review surfaced consensus findings on over-abstraction (CategoryPanel dropped), hidden-affordance risk (favourite long-press dropped), and "mechanical extraction" overreach (StagingPlate downgraded to provisional).

---

## Context

DOSBTS entry surfaces have grown feature-by-feature. Two concrete pressures drive this spec — neither is a user-reported pain:

**1. Maintenance surface.** `FoodPhotoAnalysisView` is 882 lines and conflates AI analysis, staging-review, follow-up conversational clarification, inline barcode-child navigation, cross-row focus coordination, portion scaling, and final commit into one view. It is the largest view in the app and the one most likely to be disturbed during unrelated refactors.

**2. Forward-looking code reuse.** Three upcoming surfaces (DMNC-796 unified entry interactions; DMNC-797 micro-interactions polish; DMNC-791 Figma library prep) will re-solve the same sub-problems — numeric input with custom step + tap-to-type, relative-time picker, batch item review — unless shared primitives exist.

The original drift symptoms (different views of the same concept looking different to a reviewer) are real but they aren't the user-facing driver. This spec makes that explicit so the scope stays honest: we're extracting primitives where the maintenance/reuse case is clear, and we're **not** pre-committing to larger abstractions (batch-review surface, category-wrapping panels) whose shape will only become clear after the first in-place migration.

## Object catalog

### Entry objects

#### Meal (`MealEntry`)
**A logged food intake event with carbs, description, and time.**

| Attribute | Type | Source |
|---|---|---|
| id | UUID | generated |
| timestamp | Date | user / now |
| mealDescription | String (≤200) | user / AI / barcode / favourite |
| carbsGrams | Double? (0–1000) | user / AI / OFF / favourite |
| analysisSessionId | UUID? | AI analysis (links to `PersonalFood` learning) |

- **State transitions:** staged → logged → edited | deleted
- **CTAs:** add (photo / barcode / text / manual / favourite), edit, delete, save-as-favourite
- **Relationships:**
  - → **GlucoseReading** — 2-hour post-meal impact window (`MealImpactStore` middleware)
  - → **InsulinDelivery** — bolus coverage / confounder detection
  - → **PersonalFood** — UUID-convention link via `analysisSessionId` (not a typed reference; runtime join at `ChartView.swift:735-736`)
  - ← **Favourite** — factory-method link via `FavoriteFood.from(mealEntry:)` + `.toMealEntry()` (not a stored back-reference)
- **Approach:** In-place decomposition of the 882-LOC `FoodPhotoAnalysisView` first (tracked in DMNC-800). A reusable batch-review component (Pattern 1) is provisional and extracted only if the in-place refactor reveals a clean shared shape. **Favourite tap = 1-tap direct log (unchanged).** Edit-before-log is out of scope; post-log edit remains available via chart-marker tap (already implemented).

#### InsulinDelivery (`InsulinDelivery`)
**A logged insulin dose of a given type, at a given time, with duration (basal only).**

| Attribute | Type | Source |
|---|---|---|
| id | UUID | generated |
| starts | Date | user / now |
| ends | Date | = starts (bolus) / user (basal) |
| units | Double (>0) | user |
| type | `InsulinType` (`mealBolus` / `snackBolus` / `correctionBolus` / `basal`) | user |

- **State transitions:** logged → edited | deleted
- **CTAs:** add, edit (chart marker tap), delete
- **Relationships:**
  - → **GlucoseReading** — IOB projection (oref0 Maksimovic exponential decay, DIA-window filtered; see `IOBCalculator`, `IOBMiddleware`)
  - ← **Meal** — meal / snack bolus coverage (confounder for meal-impact analysis)
- **Approach:** Inline redesign of `AddInsulinView` using the shared primitives (`StepperField`, `QuickTimeChips`) directly, with a plain `Picker(.segmented)` for type + `switch` on the enum in body. **No category-wrapping component.** See § Pattern 2 for the primitives.

#### BloodGlucose (`BloodGlucose`)
**A manually logged / fingerstick blood glucose value at a given time. Used for sanity checks and calibration.**

| Attribute | Type | Source |
|---|---|---|
| id | UUID | generated |
| timestamp | Date | user / now |
| glucoseValue | Int (mg/dL, ~40–500) | user |

- **State transitions:** logged → deleted (rarely edited)
- **CTAs:** add, delete
- **Relationships:** → **GlucoseReading** (calibration input; may influence `CustomCalibration` regression)
- **Approach:** **Direct entry — no change.** `AddBloodGlucoseView` (54 LOC) + `NumberSelectorView` is already the right shape. May later adopt `StepperField` for Int-vs-Double parity once that primitive ships, but that's out of scope here.

### Read / monitoring objects

- **GlucoseReading (`SensorGlucose`)** — primary read object. Continuous sensor-derived values with smoothed trend and minute-change slope. **Central data spine** — every entry object relates to it (impact, IOB, calibration), every derived object reads from it.
- **Sensor (`Sensor`)** — physical BLE/NFC transmitter. Lifecycle: `paired → active → expired`.
- **TreatmentCycle** — guided Rule-of-15 hypo workflow (`TreatmentCycleMiddleware`). Lifecycle: `prompted → active (countdown) → rechecking → stabilised | treat-again`. References **GlucoseReading** (recheck target) and **Meal** (hypo treatment entries via the hypo-filtered variant of `UnifiedFoodEntryView`).
- **Alarm** — threshold event (low / high / predictive-low). Lifecycle: `fired → snoozed | acknowledged`. Derived from GlucoseReading evaluation; may trigger TreatmentCycle.
- **DailyDigest (`DailyDigest`)** — per-day aggregated stats + AI insight (Claude Haiku). Lifecycle: `computed-on-demand → cached`. Aggregates all three entry objects + GlucoseReading + Exercise.
- **Exercise** — HealthKit-imported workout. Read-only in DOSBTS — no entry path. Referenced by `MealImpact` confounder detection and DailyDigest timeline.
- **Favourite (`FavoriteFood`)** — meta-object. Curated Meal template with pre-set name and carbs. Factory-method link to Meal (not a stored back-reference).
- **Goal/limit** — setting, not a logged object. `alarmLow` / `alarmHigh` / glucose target range. Referenced by Alarm (thresholds), chart band colouring, DailyDigest (TIR%).

## Object map

SVG at `.devjournal/sessions/dmnc-795-ooux-brainstorm-2026-04-23/L2-thematic/object-map.svg`. *Note: the SVG shows `[P1] StagingPlate` and `[P2] CategoryPanel` labels from the pre-review draft. Treat those as "slot names we may or may not fill with reusable components"; the committed approach (this revision) is primitives-only for Insulin and provisional for Meal.*

ASCII fallback:

```
                        ┌───────────┐
                        │  SENSOR   │
                        └─────┬─────┘
                              │ source
                              ▼
┌──────────┐         ┌──────────────────────┐         ┌──────────┐
│ FAVOURITE│─ tpl ─▶│   GLUCOSE READING     │◀─ HK ──│ EXERCISE │
└──────────┘         │ (central data spine) │         └──────────┘
                     └──▲────▲────▲─────────┘
                   impact│   │    │calibration
                         │  IOB   │
┌────────────┐           │   │    │           ┌─────────────────┐
│   MEAL     │───────────┘   │    └───────────│   INSULIN       │
│ (Pattern 1 │◀── bolus pairing / confounder ─│   DELIVERY      │
│ provisional)│                │                │ (primitives)    │
└────────────┘                 │                └─────────────────┘
      │                        │                      │
      │                        ▼                      │
      │                   ┌────────┐                  │
      │          ┌────────│ ALARM  │◀─ thresholds ────┤
      │          │        └───┬────┘  (Goal/limit)    │
      │          │            │ trigger               │
      │          │            ▼                       │
      │          │     ┌──────────────┐               │
      │          └─────│  TREATMENT   │─ recheck ─────┤
      │                │    CYCLE     │               │
      │                └──────────────┘               │
      │                                               │
  ┌───▼────────────────────────────────────────────▼───┐
  │ BLOOD GLUCOSE         DAILY DIGEST                  │
  │ (direct entry)   ◀── aggregates GR + all entry ──▶  │
  └─────────────────────────────────────────────────────┘
```

## Pattern 1 — Batch-review surface (provisional; extraction deferred)

**Status.** The batch-review concept is real — food photo, barcode, text, and manual paths all produce a small list of candidate items the user should see and edit before a single commit. But the reusable component API cannot be responsibly designed before the first real extraction attempt. This section names **open questions** DMNC-800 must answer during its in-place decomposition of `FoodPhotoAnalysisView`.

**Why not commit an API now.** The only current staging-plate code lives in `FoodPhotoAnalysisView.swift` (882 LOC) and has five concerns tangled with the generic review surface:

1. **AI follow-up conversation state** — `followUpHistory`, `isFollowingUp`, `followUpRoundsUsed` currently mutate `stagedItems` from inside the plate UI (`resultsSection`, roughly lines 315-332 and 553-598). Does this state live in a wrapper the caller supplies, or inside the plate?
2. **Inline child navigation** — inline barcode scan (lines 447-471) pushes a `NavigationLink` from inside an item row. A `itemRow: (Binding<Item>) -> ItemRow` closure has no way to coordinate with a parent-scoped navigation destination. Where does this edge live?
3. **Cross-row `@FocusState`** — `focusedItemID: UUID?` coordinates focus across sibling rows. A closure-supplied row cannot naturally share focus state with siblings without an ambient environment value. What's the mechanism?
4. **Batch-meta dependency on items** — portion picker visibility depends on `stagedItems.first?.baseServingG`. A `() -> BatchMeta` closure without `items` access fails this; closure signature probably needs `([Item]) -> BatchMeta`.
5. **Store-subscription handlers** — `.onChange(of: store.state.foodAnalysisResult)` handlers inside the staging section are semantically coupled to the plate, not the caller. Do they move into an extracted component or stay at the parent?

**Provisional API sketch** (reference for DMNC-800's author; not a committed signature):

```swift
// Provisional — actual shape determined by DMNC-800's in-place refactor.
struct StagingPlate<Item: Identifiable, BatchMeta: View, ItemRow: View>: View {
    @Binding var items: [Item]
    @Binding var batchTimestamp: Date
    @ViewBuilder let itemRow: (Binding<Item>) -> ItemRow
    @ViewBuilder let batchMeta: ([Item]) -> BatchMeta   // takes items, per open-question #4
    let canCommit: ([Item]) -> Bool
    let onCommit: ([Item], Date) -> Void
    let onCancel: () -> Void
    var allowAddItem: Bool = false
    var addItemHandler: (() -> Void)? = nil
}
```

**Recommended sequence** (tracked in DMNC-800):

1. Decompose `FoodPhotoAnalysisView` in place — extract private subviews, separate AI-specific state from staging state, resolve the five concerns above by reading the actual code.
2. *Only after step 1* — lift the shared batch-review surface into `Library/DesignSystem/Components/` if the shared shape has become obvious. If it hasn't, ship the in-place decomposition alone and re-raise when a second consumer appears.

## Pattern 2 — Shared primitives for single-object entry

**Purpose.** Provide two reusable SwiftUI primitives — a numeric field with stepper + tap-to-type, and a relative-time picker — that `AddInsulinView` (DMNC-799) and downstream work use **directly**, without an intermediate category-wrapping component.

**Decision — no `CategoryPanel` wrapper.** An earlier draft proposed `CategoryPanel<Category, Panel>` generic wrapping a segmented toggle + conditional panel closure. Three reviewers (scope-guardian, product-lens, adversarial) flagged it as renaming plain SwiftUI idioms (`Picker(.segmented)` + `switch` in body) with only one current consumer and no second proposed. Strip the wrapper and nothing of substance remains. We've dropped the wrapper; `AddInsulinView` will use the primitives directly. A second consumer with a category axis can re-raise the wrapper question.

### StepperField

```swift
struct StepperField: View {
    let title: String
    @Binding var value: Double?        // nil = empty field; [-] / [+] treat nil as 0, clamp to range
    let step: Double
    let range: ClosedRange<Double>
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1))
}
```

**Composition** (not using SwiftUI's native `Stepper`, which requires non-optional `V: Strideable`):

```
[ − ]  [  4.5  ]  [ + ]
         ^ tap to type via .decimalPad keyboard
```

- `[−]` / `[+]` buttons wrap a proxy Binding that treats `nil` as `0`, applies `step`, and clamps to `range` (buttons disable at range bounds).
- Middle value is a `TextField` with `.keyboardType(.decimalPad)`; tapping shows the keyboard for direct entry. On blur / commit, an out-of-range typed value reverts to the previous value (visual flash, no alert).

### QuickTimeChips

```swift
struct QuickTimeChips: View {
    let title: String
    @Binding var date: Date
    var presets: [TimeOffset] = [.now, .minus(15), .minus(30), .minus(60)]
}

enum TimeOffset: Hashable {
    case now
    case minutes(Int)   // negative = earlier than now
}
```

**Composition:**

```
[ NOW ] [ −15m ] [ −30m ] [ −1h ] [ ⋯ ]
                                    ^ tap opens native DatePicker(.compact) popover
```

**`NOW` semantics (medically significant).** Tapping `NOW` captures `Date()` **at tap time** and stores it. It does not drift with wall-clock time as the user continues editing other fields. This is intentional: a user tapping `NOW` then spending three minutes on the Units field wants the timestamp to reflect when they tapped `NOW`, not when they tapped Add. The chip visually highlights as selected until another chip or the custom picker is chosen.

**Popover fallback on iPhone.** iOS `.popover(attachmentAnchor:arrowEdge:)` on a button renders as a sheet on compact size classes. For iPhone this is acceptable (the sheet is small, presents the DatePicker, dismisses on selection) but it differs from the popover rendering on iPad. If the sheet fallback proves janky, DMNC-799 can switch to an explicit `.sheet` with `.presentationDetents([.height(280)])` for predictability on both idioms.

### Visual treatment

Chips and the segmented type-row use the existing DOSBTS chip pattern at `UnifiedFoodEntryView.swift:109-113`:

- Unselected: `AmberTheme.amber` border, black background, amber text.
- Selected: amber fill, black text.
- Disabled: `AmberTheme.amberDark` border, amber-dark text.

**Do not** use SwiftUI's `.pickerStyle(.segmented)` (renders iOS system-gray — most visible possible break from the DOS amber aesthetic). Wrap the `Picker` in a custom amber-chip view, or skip `Picker` entirely and lay out chips manually with `ForEach` + buttons.

### Illustrative usage — rewritten `AddInsulinView`

```swift
// Type selector — custom amber-chip row (not .pickerStyle(.segmented)).
HStack(spacing: DOSSpacing.xs) {
    ForEach(InsulinType.allCases, id: \.self) { type in
        AmberChip(
            label: type.shortLabel,
            selected: insulinType == type,
            action: { insulinType = type }
        )
    }
}
.onChange(of: insulinType) { oldType, newType in
    // Field retention: Units + Time persist (both panels need them).
    // Ends resets only when leaving basal (panel-specific field).
    if oldType == .basal, newType != .basal { ends = starts }
}

VStack(spacing: DOSSpacing.md) {
    StepperField("Units", value: $units, step: 0.5, range: 0...50)
    QuickTimeChips("Time", date: $starts)

    if insulinType == .basal {
        DatePicker("Ends", selection: $ends, displayedComponents: [.date, .hourAndMinute])
    }
    if insulinType == .correctionBolus, (currentIOB ?? 0) > 0.05 {
        IOBStackingWarning(iob: currentIOB ?? 0)
    }
}

// Toolbar Add:
Button("Add") {
    guard let units else { return }
    store.dispatch(.addInsulinDelivery(starts, ends, units, insulinType))
    dismiss()
}
```

Illustrative only — actual call-site code lands in DMNC-799. `AmberChip` is a new shared view extracted from the `UnifiedFoodEntryView` pattern at the time of DMNC-799's landing.

### Prerequisites DMNC-799 must add

- `InsulinType: CaseIterable` — add conformance to the enum in `Library/Content/InsulinDelivery.swift` (currently `Codable` only).
- `InsulinType.shortLabel: String` — chip-row tokens (`MEAL` / `SNACK` / `CORR` / `BASAL`); distinct from existing `localizedDescription`.
- `IOBStackingWarning` view — extract from the inline `HStack` at `AddInsulinView.swift:71-78` (icon + caption, amber).
- `AmberChip` view — extract from the chip pattern at `UnifiedFoodEntryView.swift:109-113` so both the QUICK favourites row and the InsulinType segmented row share the same component.

### Category-switch field retention

When the user switches InsulinType mid-entry: **fields present in both panels retain their value; panel-specific fields reset.** Concretely for insulin: Units and Time persist across type switches; Ends (basal-only) reset to `starts` when leaving basal. This preserves partial entries across related categories and avoids surprise data loss.

## Per-feature mapping

| Entry object | Current view (LOC) | Approach | Notes |
|---|---|---|---|
| **Meal** | `UnifiedFoodEntryView` (567) + `FoodPhotoAnalysisView` (882) + `AddMealView` (97) | In-place decomposition first; reusable batch-review component deferred | DMNC-800 does the in-place refactor and resolves Pattern 1's open questions. Favourite tap = 1-tap direct log (**unchanged**). **Long-press edit dropped** — post-log edit via chart-marker tap remains the supported path. `AddMealView` stays as the edit-existing-entry view. The post-migration shape of `UnifiedFoodEntryView` (menu vs. container vs. replaced) is determined by DMNC-800, not this spec. |
| **InsulinDelivery** | `AddInsulinView` (124) | Inline redesign using `StepperField` + `QuickTimeChips` + `AmberChip` | DMNC-799 rewrites AddInsulinView: custom amber-chip type row + primitives + conditional panels. No category-wrapping component. Prerequisites: `CaseIterable`, `shortLabel`, `IOBStackingWarning`, `AmberChip`, `TimeOffset`. |
| **BloodGlucose** | `AddBloodGlucoseView` (54) | Direct entry (unchanged) | May later adopt `StepperField` for Int-vs-Double parity once that primitive ships. Deferred. |

## Out-of-scope & follow-ups

**Explicitly out of scope:**

- **Calibration** (`AddCalibrationView`, 96 LOC) — specialised `CustomCalibration` regression-math flow. Stays as-is.
- **Exercise** — HealthKit-imported, read-only.
- **`CategoryPanel` wrapper** — considered and descoped (see § Pattern 2 decision). Re-raise when a second single-object-with-categories consumer appears.
- **Favourite long-press to edit** — dropped. Post-log edit via chart-marker tap (already implemented) is the supported path. Hidden gestures in a medical app are a net negative without user evidence of demand.
- **Reusable batch-review component (`StagingPlate`)** — provisional only (§ Pattern 1). Committed API emerges from DMNC-800's in-place refactor, not from this spec.
- **Accessibility specs for the new primitives** — VoiceOver labels, minimum tap targets, Dynamic Type handling — belong in DMNC-797 (micro-interactions polish). Named here so the gap is explicit.

**Follow-ups:**

- **[DMNC-798](https://linear.app/lizomorf/issue/DMNC-798)** — rescoped: build `StepperField` + `QuickTimeChips` + `AmberChip` as shared primitives. **No `StagingPlate`, no `CategoryPanel`.** Smaller scope than the pre-review draft.
- **[DMNC-799](https://linear.app/lizomorf/issue/DMNC-799)** — rescoped: rewrite `AddInsulinView` using the primitives inline (plain amber-chip type row + `switch` in body). No wrapper component. Prerequisites (CaseIterable, shortLabel, IOBStackingWarning, AmberChip) land as part of this PR.
- **[DMNC-800](https://linear.app/lizomorf/issue/DMNC-800)** — rescoped: in-place decomposition of `FoodPhotoAnalysisView` + resolution of Pattern 1's open questions. Reusable `StagingPlate` extraction is a stretch goal contingent on the in-place refactor revealing a clean shape. Favourite long-press is **not** part of this issue anymore.

**Sibling issues:**

- **DMNC-791** (Figma library decision) — the object catalog feeds this. Related but not hard-blocked.
- **DMNC-797** (micro-interactions polish) — lands on top of the shared primitives once they exist.
- **DMNC-796** (unified entry interactions — tap/long-press semantics) — this is where long-press decisions are properly owned. DMNC-795 no longer pre-decides favourite long-press.

## Success criteria

The spec is "done enough" to hand to follow-up implementation planning when all five hold:

1. Every entry object has a clear approach assignment **with rationale** — not just a table cell.
2. `StepperField` + `QuickTimeChips` API surfaces are concrete enough that a reviewer can sketch `AddInsulinView`'s rewrite from the signatures alone. Pattern 1's open-questions list is concrete enough that DMNC-800's author knows what to resolve during the in-place refactor.
3. The per-feature mapping names owner view file paths **and** LOC so migration scope is legible.
4. Out-of-scope items have stated reasons + named follow-up Linear issues (DMNC-798/799/800) so nothing is left hanging.
5. Every relationship in the object map is traceable to specific code — **either** as a typed reference (grep the target type's name in the source type's file) **or** as a documented UUID / factory-method convention (the convention is named in the catalog entry itself). Meal↔PersonalFood is the latter (via `analysisSessionId: UUID`, runtime join at `ChartView.swift:735-736`); Meal↔FavoriteFood is the latter (via `FavoriteFood.from(mealEntry:)` + `.toMealEntry()` factories). Explicitly naming the relationship kind prevents aspirational-spec drift without requiring every link to be strictly typed.
