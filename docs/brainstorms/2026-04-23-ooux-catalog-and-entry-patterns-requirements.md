# OOUX Catalog + Entry Patterns

**Issue:** [DMNC-795](https://linear.app/lizomorf/issue/DMNC-795) (High)
**Scope:** Design-only. Defines object catalog + two shared interaction patterns + per-feature mapping. Component implementation and view migrations are split into separate follow-up Linear issues (enumerated in § Out-of-scope & follow-ups).
**Unblocks:** DMNC-791 (Figma library decision), DMNC-796 (unified entry interactions), DMNC-797 (micro-interactions polish).

---

## Context

Interactions across DOSBTS — food entry, insulin entry, chart tags, marker lane groupings, favourites — have grown feature-by-feature and behave differently in each place. The app feels inconsistent because there is no shared object vocabulary or interaction contract between surfaces.

Concrete examples of the drift:

- `FoodPhotoAnalysisView` has a fully-developed staging plate (882 LOC God-View); no other entry surface does.
- `UnifiedFoodEntryView`'s favourites chip row *looks* like it should expand or route through review — it commits directly on tap.
- `AddInsulinView` uses a plain SwiftUI `Picker` menu for type; chip/segmented-row vocabulary exists elsewhere but not here.
- `EventMarkerLaneView` already implements a clean expand-in-context pattern for grouped chart markers — but only for viewing existing entries, not for entry itself.

This spec resolves the drift by (1) cataloging the objects the user thinks about, (2) extracting two reusable interaction patterns, and (3) mapping each entry object to a pattern or explicitly noting when it uses neither.

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
  - → **PersonalFood** — glycemic-score learning via `analysisSessionId`
  - ← **Favourite** — `FavoriteFood` templates populate Meal with one tap
- **Pattern:** Pattern 1 (StagingPlate) for photo / barcode / text / manual. Favourite shortcut: tap = 1-tap direct log *(preserves today's behaviour)*; long-press = open in StagingPlate for edit.

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
- **Pattern:** Pattern 2 (CategoryPanel). Units via `StepperField` + tap-to-type; time via `QuickTimeChips` + `⋯` custom. `type == .basal` reveals the second date picker for `ends`. `type == .correctionBolus` with IOB > 0.05U surfaces the stacking warning.

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
- **Pattern:** **Direct entry — neither Pattern 1 nor Pattern 2 applies.** Single value, single time, no category axis, no list to review. `AddBloodGlucoseView` (54 LOC) + `NumberSelectorView` is already the right shape and stays as-is. Documented here explicitly so future readers do not read omission as oversight.

### Read / monitoring objects

- **GlucoseReading (`SensorGlucose`)** — primary read object. Continuous sensor-derived values with smoothed trend and minute-change slope. **Central data spine** — every entry object relates to it (impact, IOB, calibration), every derived object reads from it.
- **Sensor (`Sensor`)** — physical BLE/NFC transmitter. Lifecycle: `paired → active → expired`. Surfaces in Settings and the lock-screen `SensorWidget` lifetime gauge.
- **TreatmentCycle** — guided Rule-of-15 hypo workflow (`TreatmentCycleMiddleware`). Lifecycle: `prompted → active (countdown) → rechecking → stabilised | treat-again`. References **GlucoseReading** (recheck target) and **Meal** (hypo treatment entries via the hypo-filtered variant of `UnifiedFoodEntryView`).
- **Alarm** — threshold event (low / high / predictive-low). Lifecycle: `fired → snoozed | acknowledged`. Derived from GlucoseReading evaluation; may trigger TreatmentCycle.
- **DailyDigest (`DailyDigest`)** — per-day aggregated stats + AI insight (Claude Haiku). Lifecycle: `computed-on-demand → cached`. Aggregates all three entry objects + GlucoseReading + Exercise.
- **Exercise** — HealthKit-imported workout. Read-only in DOSBTS — no entry path. Referenced by `MealImpact` confounder detection and DailyDigest timeline.
- **Favourite (`FavoriteFood`)** — meta-object. Curated Meal template with pre-set name and carbs. Sits between the catalog and logging.
- **Goal/limit** — setting, not a logged object. `alarmLow` / `alarmHigh` / glucose target range. Referenced by Alarm (thresholds), chart band colouring, DailyDigest (TIR%).

## Object map

SVG is in the devjournal session for this spec at `.devjournal/sessions/dmnc-795-ooux-brainstorm-2026-04-23/L2-thematic/object-map.svg`. ASCII fallback:

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
┌────[P1]────┐           │   │    │           ┌────[P2]─────┐
│   MEAL     │───────────┘   │    └───────────│   INSULIN   │
│            │◀── bolus pairing / confounder ─│   DELIVERY  │
└────────────┘                │                └─────────────┘
      │                       │                      │
      │                       ▼                      │
      │                  ┌────────┐                  │
      │         ┌────────│ ALARM  │◀─ thresholds ────┤
      │         │        └───┬────┘  (Goal/limit)    │
      │         │            │ trigger               │
      │         │            ▼                       │
      │         │     ┌──────────────┐               │
      │         └─────│  TREATMENT   │─ recheck ─────┤
      │               │    CYCLE     │               │
      │               └──────────────┘               │
      │                                              │
  ┌───▼────────────────────────────────────────────▼───┐
  │ BLOOD GLUCOSE         DAILY DIGEST                  │
  │ [direct entry]   ◀── aggregates GR + all entry ──▶  │
  └─────────────────────────────────────────────────────┘
```

## Pattern 1 — StagingPlate

**Purpose.** Shared batch-review surface used whenever input produces a list of candidate items that the user should see and edit before a single commit.

**API surface** (SwiftUI, generic over item type):

```swift
struct StagingPlate<Item: Identifiable, BatchMeta: View, ItemRow: View>: View {
    @Binding var items: [Item]
    @Binding var batchTimestamp: Date

    // Slots (caller-supplied)
    let itemRow: (Binding<Item>) -> ItemRow        // one editable row per item
    let batchMeta: () -> BatchMeta                 // optional batch-level fields (e.g. portion multiplier)

    // Behaviour
    let canCommit: ([Item]) -> Bool                // validation predicate
    let onCommit: ([Item], Date) -> Void           // commit handler (single batch → single store dispatch)
    let onCancel: () -> Void

    // Optional add-item affordance
    var allowAddItem: Bool = false
    var addItemHandler: (() -> Void)? = nil        // e.g. open barcode scanner inline
}
```

**Design rationale.** Generic struct with ViewBuilder closures rather than a `StagingPlateItem` protocol. SwiftUI protocols over generic views are awkward (associated-type constraints, type-erasure pain) and we only have one concrete item type today (`EditableFoodItem`). Protocol extraction can happen later if a second item type appears.

**Observed states:**

| State | Meaning | User can… |
|---|---|---|
| `idle` | items populated, no pending action | edit rows, remove, add, cancel, commit |
| `committing` | `onCommit` in-flight | nothing (disabled); show progress |
| `error` | commit failed | see toast + re-enable |

Progress / error rendering is the caller's concern (via external state passed through `batchMeta` or a sibling view). StagingPlate itself just toggles interactivity.

**Shared sub-components introduced alongside:**

- `ItemRowDefault` — optional default editable row (name + numeric amount) for callers that don't want to supply their own. Opt-in, not required.
- `BatchCommitBar` — bottom commit/cancel bar with a total-summary slot. Extracted so multi-item flows share the same commit UX.

**Existing code to extract from.** `App/Views/AddViews/FoodPhotoAnalysisView.swift` — the 882-LOC God View contains the only current staging plate. Extraction is *not in scope for this spec* but the API is chosen so the migration is mechanical:

- current `stagedItems` → `@Binding items`
- `editTimestamp` → `@Binding batchTimestamp`
- `portionMultiplier` + `customPortionText` → inside `batchMeta`
- current `[+ add item]` row → `allowAddItem` + `addItemHandler`

## Pattern 2 — CategoryPanel

**Purpose.** Shared single-object entry surface where the object has a category axis (enum of types) and each category may render different inline inputs.

**API surface** (SwiftUI, generic over the category enum):

```swift
struct CategoryPanel<Category: Hashable, Panel: View>: View {
    @Binding var selected: Category
    let categories: [Category]
    let chipLabel: (Category) -> String

    let panel: (Category) -> Panel                 // inline attribute panel for the selected category
    let canCommit: () -> Bool
    let onCommit: () -> Void
    let onCancel: () -> Void
}
```

**Sub-components (shared primitives introduced alongside):**

```swift
struct StepperField: View {
    let title: String
    @Binding var value: Double?        // nil = empty field (tap-to-type clearable, matches today's Double? pattern)
    let step: Double
    let range: ClosedRange<Double>
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1))
}   // [−step] [value, tap-to-type decimal pad] [+step]  — [−] / [+] treat nil as 0

struct QuickTimeChips: View {
    let title: String
    @Binding var date: Date
    var presets: [TimeOffset] = [.now, .minus(15), .minus(30), .minus(60)]
}   // [NOW] [−15m] [−30m] [−1h] [⋯ → native picker]
```

`QuickTimeChips`' `⋯` chip opens the native `DatePicker(.compact)` in a popover — retains the unrestricted escape hatch without pulling the native picker into the primary row.

**Illustrative usage — `InsulinDelivery`:**

```swift
CategoryPanel(
    selected: $insulinType,
    categories: InsulinType.allCases,
    chipLabel: { $0.shortLabel }
) { type in
    VStack(spacing: DOSSpacing.md) {
        StepperField("Units", value: $units, step: 0.5, range: 0...50)
        QuickTimeChips("Time", date: $starts)
        if type == .basal {
            DatePicker("Ends", selection: $ends, displayedComponents: [.date, .hourAndMinute])
        }
        if type == .correctionBolus, (currentIOB ?? 0) > 0.05 {
            IOBStackingWarning(iob: currentIOB ?? 0)
        }
    }
}
canCommit: { (units ?? 0) > 0 }
onCommit: { store.dispatch(.addInsulinDelivery(starts, ends, units!, insulinType)) }
onCancel: { dismiss() }
```

Illustrative only — actual call-site code lands in the `AddInsulinView`-migration follow-up issue, not here.

## Per-feature mapping

| Entry object | Current view (LOC) | New pattern | Notes |
|---|---|---|---|
| Meal | `UnifiedFoodEntryView` (567) + `FoodPhotoAnalysisView` (882) + `AddMealView` (97) | **Pattern 1** (StagingPlate) | Photo / barcode / text → StagingPlate. Manual path reuses StagingPlate's default item-row with a prepopulated empty item. **Favourite tap = 1-tap direct log — preserves today's behaviour, not a new design.** **Long-press favourite → StagingPlate** for edit before log. `AddMealView` stays for editing an existing `MealEntry` (tapped from chart markers / Lists tab); its role as a standalone *new-entry* surface goes away. |
| InsulinDelivery | `AddInsulinView` (124) | **Pattern 2** (CategoryPanel) | Categories = `InsulinType.allCases`. `basal` reveals extra `Ends` DatePicker inside the panel closure. `correctionBolus` with live IOB > 0.05 renders stacking warning inside the panel closure. |
| BloodGlucose | `AddBloodGlucoseView` (54) | **Direct entry** | Unchanged. `NumberSelectorView` + `DatePicker` already fit. No category axis, no batch to review. |

## Out-of-scope & follow-ups

**Explicitly out of scope:**

- **Calibration** (`AddCalibrationView`, 96 LOC) — specialised `CustomCalibration` regression-math flow. Neither pattern benefits it. Stays as-is.
- **Exercise** — HealthKit-imported, read-only. No entry path in DOSBTS.
- **Component implementation** — Swift code for `StagingPlate`, `CategoryPanel`, `StepperField`, `QuickTimeChips` is not written in this spec. Becomes a Linear follow-up issue.
- **`AddInsulinView` migration** — Pattern 2 proof-point. Separate follow-up issue.
- **`UnifiedFoodEntryView` + `FoodPhotoAnalysisView` rewire** — extracts the staging plate from the 882-LOC God View, adds favourite long-press, routes all meal paths through Pattern 1. Separate follow-up issue.

**Sibling issues this spec unblocks:**

- **DMNC-791** (Figma + prototype workflow) — the object catalog here feeds the Figma component-library decision.
- **DMNC-796** (Unified entry interactions — expand-from-tag + tap-vs-long-press semantics) — builds on Pattern 2's CategoryPanel + Pattern 1's StagingPlate long-press affordance.
- **DMNC-797** (Duolingo-smooth micro-interactions) — motion / spring work lands on top of stable component APIs, not ad-hoc Forms.

## Success criteria

The spec is "done enough" to hand to follow-up implementation planning when all five hold:

1. Every entry object has a clear pattern assignment **with rationale** — not just a table cell.
2. `StagingPlate` + `CategoryPanel` API surfaces are concrete enough that a reviewer can sketch `AddInsulinView`'s rewrite from the signatures alone.
3. The per-feature mapping table names owner view file paths **and** LOC so migration scope is legible.
4. Out-of-scope items have stated reasons + suggested follow-up Linear issue titles so nothing is left hanging.
5. Every relationship drawn in the object map is verifiable — a reviewer can grep for the referenced Swift types and find the actual linkage in code. This is the gate against "aspirational spec" drift.
