# DMNC-848 Core Unified Entry Plan (v2 — post doc-review)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bare insulin `confirmationDialog` and standalone meal-impact card with a unified Libre-style list overlay → combined edit modal flow. Adapt the existing `EventMarkerLaneView` rather than building parallel types.

**Architecture:** Adapt existing `EventMarkerLaneView` (171 LOC, already cross-type with consolidation) to dispatch a single `onTapGroup(ConsolidatedMarkerGroup)` callback in addition to today's `onTapMeal`/`onTapInsulin`. Promote `EventMarker`/`ConsolidatedMarkerGroup`/`EventMarkerType` from ChartView-private to `Library/Content/` for sharing. New `EntryGroupListOverlay` (read surface) renders a `ConsolidatedMarkerGroup` chronologically with rich sub-lines (IN PROGRESS, confounders, PersonalFood avg, IOB, mmol/L). New `CombinedEntryEditView` (edit surface, sheet-swap from list overlay via `pendingSheet`/`onDismiss`) edits an existing group with id-preserving constructors. New design-system primitives (`AmberChip`, `StepperField`, `QuickTimeChips`) back the redesigned `AddInsulinView`. Per-item plate row extracted into `StagingPlateRowView`.

**Tech Stack:** SwiftUI, SwiftUI Charts, Combine, Redux-like Store (`DirectStore`), GRDB, Swift Testing (`@Test`/`#expect`) under XCTest target `DOSBTSTests`.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` (D1, D2, D3, D4, D5, D8).

**Out of scope (separate plans):** D6 HR overlay, D7 strict-separation toggle.

**Doc-review revisions from v1 (highlights):**
- Use id-preserving constructors instead of mutating `let` fields on `MealEntry`/`InsulinDelivery`.
- Add `CaseIterable` to `InsulinType` (Phase 0).
- Use real field names: `ExerciseEntry.startTime`, `.activityType` (not `startDate`/`workoutType`).
- Use real DataStore API: middleware dispatches `.loadMealEntryValues` (not phantom `fetchMealEntries()`); file is `MealStore.swift` (not `MealEntryStore.swift`).
- Adapt existing `EventMarkerLaneView` (do not create parallel `MarkerLaneView`).
- Reuse existing `updateMarkerGroups()` zoom-aware grouping (do not invent fixed-15-min `groupAll`).
- ChartView callback closure for marker tap, not a Redux round-trip via new `setSelectedEntryGroup` action.
- Drop ChartView's existing `.sheet(item: $tappedMealEntry)` + `$tappedMealGroup` to avoid sibling-sheet collisions.
- Hoist `EditableFoodItem` out of `FoodPhotoAnalysisView.swift` to `Library/Content/`.
- Combined modal hydrates from `analysisSessionId` (or shows banner) instead of silent collapse to single row.
- `save()` updates only — no auto-create from empty companions.
- Preserve `proteinGrams`/`fatGrams`/`calories`/`fiberGrams`/`analysisSessionId` on meal update.
- List overlay restores IN PROGRESS / confounders / PersonalFood avg / mmol/L formatting.
- Combined modal wraps in `ScrollView` for Dynamic Type ≥ xxxLarge or small devices.
- Test files registered in `project.pbxproj` as a single Phase 0 task (covers all 9 new test files).
- Reducer test API uses `directReducer(state:action:)` (free function, lowercase) and `AppState()` no-arg init.
- `EntryGroup`-equivalent reuses `ConsolidatedMarkerGroup` (already `Identifiable`); add `Equatable` only where SwiftUI `.onChange(of:)` requires it.
- Time control distinction (DatePicker in combined modal vs QuickTimeChips in standalone AddInsulinView) called out explicitly in Task 14.
- Barcode rescan: keep `NavigationLink`-based flow in `FoodPhotoAnalysisView`; combined modal disables rescan in v1.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `Library/DesignSystem/Components/AmberChip.swift` | Type-coloured chip primitive (`.type`, `.preset` variants). Both targets. |
| `App/DesignSystem/Components/StepperField.swift` | `[−] value [+]` numeric stepper with tap-to-type. App only. |
| `App/DesignSystem/Components/QuickTimeChips.swift` | Chip row of `AmberChip(.preset)` with `⋯` → DatePicker popover. App only. |
| `App/Views/AddViews/Components/StagingPlateRowView.swift` | Collapsed-summary + expanded-edit row used by both food entry surfaces. |
| `Library/Content/EditableFoodItem.swift` | Hoisted from `FoodPhotoAnalysisView.swift` (no field changes). |
| `Library/Content/EventMarker.swift` | Promoted from `ChartView.swift:1802–1858` (existing `EventMarkerType`, `EventMarker`, `ConsolidatedMarkerGroup`). |
| `Library/Content/InsulinImpact.swift` | View-layer computed type (no GRDB persistence). Mirrors `MealImpact`'s shape. |
| `App/Views/Overview/EntryGroupListOverlay.swift` | Libre-style list read surface (D2). |
| `App/Views/AddViews/CombinedEntryEditView.swift` | Stacked-sections edit modal (D3). |
| `DOSBTSTests/InsulinImpactTests.swift` | InsulinImpact computation. |
| `DOSBTSTests/StagingPlateRowTests.swift` | Ratio auto-scale + manual override logic. |
| `DOSBTSTests/AmberChipTests.swift`, `StepperFieldTests.swift`, `QuickTimeChipsTests.swift` | Primitive tests. |
| `DOSBTSTests/EntryGroupListOverlayTests.swift` | Sub-line formatting (meal/insulin/exercise + IN PROGRESS/PersonalFood/mmol). |

### Modified files

| Path | Change |
|---|---|
| `Library/Content/InsulinDelivery.swift` | Add `CaseIterable` conformance to `InsulinType`; add `var shortLabel: String` extension. |
| `Library/DirectAction.swift` | Add `updateMealEntry(MealEntry)`, `updateInsulinDelivery(InsulinDelivery)`. |
| `Library/DirectReducer.swift` | Handle the two new update actions (no in-memory mutation; rely on `.load*Values` round-trip from middleware). |
| `App/Modules/DataStore/MealStore.swift` | Add `updateMealEntry` middleware case; add `DataStore.shared.updateMealEntry(_:)`. |
| `App/Modules/DataStore/InsulinDeliveryStore.swift` | Add `updateInsulinDelivery` middleware case; add `DataStore.shared.updateInsulinDelivery(_:)`. |
| `App/Views/AddViews/AddInsulinView.swift` | Replace `Picker("Type")` with `AmberChip(.type)`; replace value entry with `StepperField`; replace start-date with `QuickTimeChips`; preserve existing `addCallback` contract; add Delete-with-confirmation when `editingDelivery != nil`. |
| `App/Views/Overview/EventMarkerLaneView.swift` | Bare-icon visual treatment (D1: drop borders/chips/text); add `onTapGroup: (ConsolidatedMarkerGroup) -> Void` callback parallel to existing `onTapMeal`/`onTapInsulin`; keep zoom-aware grouping driven by ChartView. |
| `App/Views/Overview/ChartView.swift` | Use the new `onTapGroup` to push an `EntryGroup` selection up. Remove `.sheet(item: $tappedMealEntry)` (~lines 198–214), `.sheet(item: $tappedMealGroup)` (~lines 227–286), `.confirmationDialog` for `tappedInsulinEntry` (~line 215), and `activeMealOverlay` inline card (~lines 575–680). Delete the `@State` properties for those. Move the meal-impact computation helpers (`computeMealOverlayDelta`, `detectMealConfounders`) to a free helper file `App/Views/Overview/MealOverlayLogic.swift` so `EntryGroupListOverlay` can call them. |
| `App/Views/OverviewView.swift` | Add `.entryGroupReadOverlay(ConsolidatedMarkerGroup)` and `.combinedEntryEdit(ConsolidatedMarkerGroup)` to `ActiveSheet` enum + sheet body. Sheet swap via existing `pendingSheet` pattern. |
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Replace inline expandable item rows with `StagingPlateRowView` (preserving the existing `NavigationLink → ItemBarcodeScannerView` pattern via the parent's wrapping). |
| `DOSBTSTests/DirectReducerTests.swift` | Cover `updateMealEntry` / `updateInsulinDelivery` (using `directReducer(state:action:)` free function, `AppState()` no-arg init). |
| `project.pbxproj` | Register all 9 new test files in `DOSBTSTests` group + `PBXSourcesBuildPhase` (single batch in Phase 0). |

---

## Phase 0 — Prep

### Task 0a: Add `CaseIterable` to `InsulinType` + shortLabel extension

**Files:**
- Modify: `Library/Content/InsulinDelivery.swift`

- [ ] **Step 1: Add `CaseIterable` conformance + shortLabel**

```swift
// Library/Content/InsulinDelivery.swift — line 10
enum InsulinType: Codable, CaseIterable {
    case mealBolus
    case snackBolus
    case correctionBolus
    case basal
}

extension InsulinType {
    var shortLabel: String {
        switch self {
        case .mealBolus: return "MEAL"
        case .snackBolus: return "SNACK"
        case .correctionBolus: return "CORR"
        case .basal: return "BASAL"
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Commit**

```bash
git add Library/Content/InsulinDelivery.swift
git commit -m "chore: InsulinType conforms to CaseIterable + adds shortLabel"
```

---

### Task 0b: Hoist `EditableFoodItem` to its own file

**Files:**
- Create: `Library/Content/EditableFoodItem.swift`
- Modify: `App/Views/AddViews/FoodPhotoAnalysisView.swift` (remove the local definition at lines 9–60)

- [ ] **Step 1: Move the struct to the new file**

Cut the entire `// MARK: - EditableFoodItem` block (lines 9–60 of `FoodPhotoAnalysisView.swift` — adjust line numbers via grep) into `Library/Content/EditableFoodItem.swift`. No field changes; preserve `id`, `name`, `carbsG`, `currentAmountG`, `baseServingG`, `carbsPerG`, `isExpanded`, plus initialiser.

- [ ] **Step 2: Build to confirm no missing references**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Commit**

```bash
git add Library/Content/EditableFoodItem.swift App/Views/AddViews/FoodPhotoAnalysisView.swift
git commit -m "refactor: hoist EditableFoodItem to Library/Content"
```

---

### Task 0c: Register all 9 new test files in pbxproj

**Files:**
- Modify: `DOSBTS.xcodeproj/project.pbxproj`

The 9 new test files this plan creates: `AmberChipTests.swift`, `StepperFieldTests.swift`, `QuickTimeChipsTests.swift`, `StagingPlateRowTests.swift`, `InsulinImpactTests.swift`, `EntryGroupListOverlayTests.swift`. (Plus existing `DirectReducerTests.swift` is modified, no new file.)

- [ ] **Step 1: Add each test file to the `DOSBTSTests` group + `PBXSourcesBuildPhase`**

Per CLAUDE.md, edit `project.pbxproj` manually:
1. Generate a stable UUID for each new file (use `uuidgen | tr -d '-' | cut -c 1-24` for each).
2. Add a `PBXFileReference` entry for each `.swift` file.
3. Add a `PBXBuildFile` entry referencing each file.
4. Append each `PBXBuildFile` UUID to the `DOSBTSTests` `PBXSourcesBuildPhase` files array.
5. Append each `PBXFileReference` UUID to the `DOSBTSTests` `PBXGroup` children array.

Create empty placeholder files first so the references resolve:
```bash
mkdir -p DOSBTSTests
touch DOSBTSTests/AmberChipTests.swift \
      DOSBTSTests/StepperFieldTests.swift \
      DOSBTSTests/QuickTimeChipsTests.swift \
      DOSBTSTests/StagingPlateRowTests.swift \
      DOSBTSTests/InsulinImpactTests.swift \
      DOSBTSTests/EntryGroupListOverlayTests.swift
```

Each file just contains:
```swift
import Testing
@testable import DOSBTSApp

@Suite("placeholder") struct PlaceholderTests {}
```

- [ ] **Step 2: Build the test target to confirm registration**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DOSBTSTests test 2>&1 | tail -10
```

Expected: 0 failures, 6 placeholder suites discovered.

- [ ] **Step 3: Commit**

```bash
git add DOSBTSTests/ DOSBTS.xcodeproj/project.pbxproj
git commit -m "chore: register DMNC-848 test files in pbxproj"
```

---

### Task 0d: Promote `EventMarker` types out of ChartView-private

**Files:**
- Create: `Library/Content/EventMarker.swift`
- Modify: `App/Views/Overview/ChartView.swift` (remove the type definitions at lines 1802–1858; keep the helpers that use them)

- [ ] **Step 1: Cut + paste types into the new file**

Move `enum EventMarkerType`, `struct EventMarker`, `struct ConsolidatedMarkerGroup` — currently at the bottom of `ChartView.swift` (~lines 1802–1858) — into `Library/Content/EventMarker.swift`. Mark them `public` if necessary (they're file-private today; promote to module-internal `internal` since the new view, the modal, and tests all need them).

- [ ] **Step 2: Add `Equatable` to `ConsolidatedMarkerGroup` (needed for SwiftUI `.onChange(of:)` later)**

```swift
// Library/Content/EventMarker.swift
extension ConsolidatedMarkerGroup: Equatable {
    static func == (lhs: ConsolidatedMarkerGroup, rhs: ConsolidatedMarkerGroup) -> Bool {
        lhs.id == rhs.id
    }
}
```

- [ ] **Step 3: Build to confirm**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 4: Commit**

```bash
git add Library/Content/EventMarker.swift App/Views/Overview/ChartView.swift
git commit -m "refactor: promote EventMarker types to Library/Content"
```

---

## Phase 1 — Design system primitives (D4)

### Task 1: AmberChip primitive

**Files:**
- Create: `Library/DesignSystem/Components/AmberChip.swift`
- Modify: `DOSBTSTests/AmberChipTests.swift` (replace placeholder)

- [ ] **Step 1: Write failing test**

```swift
import Testing
import SwiftUI
@testable import DOSBTSApp

@Suite("AmberChip")
struct AmberChipTests {
    @Test("init stores selection state")
    func selectionStored() {
        let chip = AmberChip(label: "MEAL", isSelected: true) {}
        #expect(chip.isSelected == true)
    }
}
```

- [ ] **Step 2: Run test, expect FAIL** (`AmberChip` undefined)

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DOSBTSTests/AmberChipTests
```

- [ ] **Step 3: Implement `AmberChip`**

```swift
// Library/DesignSystem/Components/AmberChip.swift
import SwiftUI

public struct AmberChip: View {
    public enum Variant {
        case type      // segmented selection chip
        case preset    // single-tap action chip
    }

    public let label: String
    public let icon: String?
    public let variant: Variant
    public let tint: Color
    public let isSelected: Bool
    public let action: () -> Void

    public init(
        label: String,
        icon: String? = nil,
        variant: Variant = .type,
        tint: Color = AmberTheme.amber,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 11)) }
                Text(label).font(DOSTypography.caption)
            }
            .padding(.horizontal, DOSSpacing.sm)
            .frame(minHeight: 28)
            .foregroundStyle(isSelected ? tint : AmberTheme.amberDark)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? tint.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? tint : AmberTheme.amberDark, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        // Replace ASCII-art labels with readable text
        switch label {
        case "⋯": return "Custom time"
        case "−15m": return "15 minutes ago"
        case "−30m": return "30 minutes ago"
        case "−1h": return "1 hour ago"
        default: return label
        }
    }
}
```

- [ ] **Step 4: Run test, expect PASS.**
- [ ] **Step 5: Commit**

```bash
git add Library/DesignSystem/Components/AmberChip.swift DOSBTSTests/AmberChipTests.swift
git commit -m "feat: add AmberChip design system primitive"
```

---

### Task 2: StepperField primitive

**Files:**
- Create: `App/DesignSystem/Components/StepperField.swift`
- Modify: `DOSBTSTests/StepperFieldTests.swift`

- [ ] **Step 1: Write failing tests for clamping**

```swift
import Testing
@testable import DOSBTSApp

@Suite("StepperField")
struct StepperFieldTests {
    @Test("incrementing past upper bound clamps")
    func clampsUp() {
        var v: Double? = 49.5
        StepperField.increment(&v, step: 0.5, range: 0...50)
        #expect(v == 50.0)
        StepperField.increment(&v, step: 0.5, range: 0...50)
        #expect(v == 50.0)
    }

    @Test("decrementing nil treats it as 0 and clamps to lower bound")
    func clampsDown() {
        var v: Double? = nil
        StepperField.decrement(&v, step: 0.5, range: 0...50)
        #expect(v == 0.0)
    }
}
```

- [ ] **Step 2: Run test, expect FAIL.**
- [ ] **Step 3: Implement `StepperField`** — same body as v1 plan Task 2 (no changes needed; existing implementation was correct).

```swift
// App/DesignSystem/Components/StepperField.swift
import SwiftUI

struct StepperField: View {
    let title: String
    @Binding var value: Double?
    let step: Double
    let range: ClosedRange<Double>
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(1))

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DOSSpacing.sm) {
            button(symbol: "minus", action: { Self.decrement(&value, step: step, range: range) })
            TextField(title, value: $value, format: format)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isFocused)
                .frame(minWidth: 60, minHeight: 28)
                .font(DOSTypography.body)
                .foregroundStyle(AmberTheme.amberLight)
            button(symbol: "plus", action: { Self.increment(&value, step: step, range: range) })
        }
        .padding(.horizontal, DOSSpacing.sm)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 2).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(AmberTheme.amberDark, lineWidth: 1))
    }

    private func button(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 2).fill(AmberTheme.amberLight))
        }
        .buttonStyle(.plain)
    }

    static func increment(_ value: inout Double?, step: Double, range: ClosedRange<Double>) {
        let current = value ?? 0
        value = min(current + step, range.upperBound)
    }

    static func decrement(_ value: inout Double?, step: Double, range: ClosedRange<Double>) {
        let current = value ?? 0
        value = max(current - step, range.lowerBound)
    }
}
```

- [ ] **Step 4: Run test, expect PASS.**
- [ ] **Step 5: Commit**

```bash
git add App/DesignSystem/Components/StepperField.swift DOSBTSTests/StepperFieldTests.swift
git commit -m "feat: add StepperField primitive with clamping logic"
```

---

### Task 3: QuickTimeChips primitive

**Files:**
- Create: `App/DesignSystem/Components/QuickTimeChips.swift`
- Modify: `DOSBTSTests/QuickTimeChipsTests.swift`

- [ ] **Step 1: Write failing test for preset offset application**

```swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("QuickTimeChips")
struct QuickTimeChipsTests {
    @Test("applying −15m preset subtracts 15 minutes from anchor")
    func minus15() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        let result = QuickTimeChips.applyPreset(.minus(15), anchor: anchor)
        #expect(result.timeIntervalSince(anchor) == -900)
    }

    @Test(".now resets to anchor")
    func now() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        #expect(QuickTimeChips.applyPreset(.now, anchor: anchor) == anchor)
    }
}
```

- [ ] **Step 2: Run test, expect FAIL.**
- [ ] **Step 3: Implement `QuickTimeChips`** — same body as v1 plan Task 3.

(Use the v1 plan's Task 3 implementation verbatim; no doc-review issues with that one.)

- [ ] **Step 4: Run test, expect PASS.**
- [ ] **Step 5: Commit**

```bash
git add App/DesignSystem/Components/QuickTimeChips.swift DOSBTSTests/QuickTimeChipsTests.swift
git commit -m "feat: add QuickTimeChips primitive"
```

---

## Phase 2 — StagingPlateRowView extraction (D5)

### Task 4: Extract StagingPlateRowView with ratio-link logic

**Files:**
- Create: `App/Views/AddViews/Components/StagingPlateRowView.swift`
- Modify: `DOSBTSTests/StagingPlateRowTests.swift`

**Design correction (from doc-review):** The view does **not** present `ItemBarcodeScannerView` directly. The barcode-rescan button calls `onBarcodeRescan(itemID)` and the parent (`FoodPhotoAnalysisView`) wraps the row in the existing `NavigationLink` flow. `CombinedEntryEditView` passes a no-op for `onBarcodeRescan` (rescan disabled in v1, documented in CHANGELOG).

- [ ] **Step 1: Write failing tests for ratio auto-scale + manual override + summary formatting**

```swift
import Testing
@testable import DOSBTSApp

@Suite("StagingPlateRow")
struct StagingPlateRowTests {
    @Test("amount change auto-scales carbs when ratio is set")
    func autoScale() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 22.5, currentAmountG: 60, baseServingG: 60, carbsPerG: 0.375)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 120)
        #expect(item.currentAmountG == 120)
        #expect(item.carbsG == 45.0)
    }

    @Test("manual carb edit breaks the ratio link")
    func manualOverride() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 45, currentAmountG: 120, baseServingG: 60, carbsPerG: 0.375)
        StagingPlateRowLogic.applyCarbsChange(item: &item, newCarbs: 50)
        #expect(item.carbsG == 50)
        #expect(item.carbsPerG == nil)
    }

    @Test("amount over 10000 clamps")
    func clampsLargeAmount() {
        var item = EditableFoodItem(name: "Test", carbsG: 0, currentAmountG: 100, baseServingG: 100, carbsPerG: 0.5)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 50000)
        #expect(item.currentAmountG == 10000)
    }

    @Test("summary text differs by amount presence")
    func summary() {
        let withAmount = EditableFoodItem(name: "Pasta", carbsG: 38, currentAmountG: 120, baseServingG: 120, carbsPerG: nil)
        let withoutAmount = EditableFoodItem(name: "Bacon", carbsG: 2, currentAmountG: nil, baseServingG: nil, carbsPerG: nil)
        #expect(StagingPlateRowLogic.summary(for: withAmount) == "120g · 38g C")
        #expect(StagingPlateRowLogic.summary(for: withoutAmount) == "2g C")
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**
- [ ] **Step 3: Implement view + logic** — same body as v1 plan Task 4. (Logic + view code in v1 was correct; only the parent wiring was wrong, fixed in Task 5.)

- [ ] **Step 4: Run tests, expect PASS.**
- [ ] **Step 5: Commit**

```bash
git add App/Views/AddViews/Components/StagingPlateRowView.swift DOSBTSTests/StagingPlateRowTests.swift
git commit -m "feat: extract StagingPlateRowView with ratio-link auto-scale"
```

---

### Task 5: Migrate FoodPhotoAnalysisView to use StagingPlateRowView (preserving NavigationLink barcode flow)

**Files:**
- Modify: `App/Views/AddViews/FoodPhotoAnalysisView.swift` (food items section, ~lines 410–550)

**Critical: keep the existing `NavigationLink → ItemBarcodeScannerView` and `isItemScanActive` pattern in the parent.** Don't lose the `onDisappear`-guard behaviour.

- [ ] **Step 1: Replace the inline `ForEach` body, but wrap each row in the existing `NavigationLink` for barcode rescan**

```swift
// FoodPhotoAnalysisView.swift — inside the food items Section
ForEach($stagedItems) { $item in
    let itemID = item.id
    StagingPlateRowView(
        item: $item,
        onBarcodeRescan: { _ in
            // Activate the parent's NavigationLink for this row by setting the scan target
            scanTargetIndex = stagedItems.firstIndex(where: { $0.id == itemID })
        },
        isExpanded: item.isExpanded,
        onToggleExpand: {
            withAnimation(.linear(duration: 0.18)) { item.isExpanded.toggle() }
        }
    )
    .background(
        // Hidden NavigationLink driven by scanTargetIndex matching this item
        NavigationLink(
            isActive: Binding(
                get: { scanTargetIndex.flatMap { stagedItems[$0].id } == itemID },
                set: { active in if !active { scanTargetIndex = nil } }
            ),
            destination: {
                ItemBarcodeScannerView { scannedEstimate in
                    isItemScanActive = false
                    if let currentIdx = stagedItems.firstIndex(where: { $0.id == itemID }),
                       let scannedItem = scannedEstimate.items.first {
                        let amount = parseBaseServingG(scannedItem.servingSize)
                        let ratio: Double? = amount.flatMap { $0 > 0 ? scannedItem.carbsG / $0 : nil }
                        stagedItems[currentIdx].name = scannedItem.name
                        stagedItems[currentIdx].carbsG = scannedItem.carbsG
                        stagedItems[currentIdx].baseServingG = amount
                        stagedItems[currentIdx].currentAmountG = amount
                        stagedItems[currentIdx].carbsPerG = ratio
                    }
                }
                .navigationBarHidden(true)
                .onAppear { isItemScanActive = true }
                .onDisappear { isItemScanActive = false }
            },
            label: { EmptyView() }
        )
        .opacity(0)
    )
}
.onDelete { offsets in
    focusedItemID = nil
    stagedItems.remove(atOffsets: offsets)
}
```

(Keep the existing `Add Item` button below.)

**What must remain unchanged in `FoodPhotoAnalysisView`:** Nutrition banner, Portion picker (conditional), Description field, Clarify section (conditional), Confidence indicator, AI disclaimer, Log Meal button, `isItemScanActive` state and its onDisappear guard.

- [ ] **Step 2: Build app**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Run on simulator. Take a photo / use favourite. Expand a row, change Amount, verify carb auto-scale. Type manual carbs, verify `manual` indicator. Tap barcode icon, verify scanner pushes (NavigationLink works), scan a real barcode (or simulator-mock), verify item updates and `stagedItems` aren't cleared on push/pop (the `isItemScanActive` guard works).**

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/FoodPhotoAnalysisView.swift
git commit -m "refactor: FoodPhotoAnalysisView uses StagingPlateRowView (barcode flow preserved)"
```

---

## Phase 3 — InsulinImpact view-layer model

### Task 6: InsulinImpact

**Files:**
- Create: `Library/Content/InsulinImpact.swift`
- Modify: `DOSBTSTests/InsulinImpactTests.swift`

- [ ] **Step 1: Write failing tests** — use v1 plan Task 8's tests verbatim (the logic was correct).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** — use v1 plan Task 8's implementation verbatim.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit**

```bash
git add Library/Content/InsulinImpact.swift DOSBTSTests/InsulinImpactTests.swift
git commit -m "feat: InsulinImpact view-layer model"
```

---

## Phase 4 — Redux update actions

### Task 7: Add `updateMealEntry` / `updateInsulinDelivery` actions + reducer (load-after-write pattern)

**Files:**
- Modify: `Library/DirectAction.swift` (two new cases)
- Modify: `Library/DirectReducer.swift` (handlers — but DO NOT mutate `*Values` arrays; rely on middleware's `.load*Values` round-trip)
- Modify: `DOSBTSTests/DirectReducerTests.swift`

**Doc-review fix:** v1 had the reducer mutate the array directly; this races the DataStore round-trip. Real pattern: the reducer is a no-op for these actions; middleware writes to GRDB then dispatches `.load*Values` which fetches and dispatches `.set*Values`.

- [ ] **Step 1: Write failing reducer test (asserting reducer no-op behaviour, since real persistence is in middleware)**

```swift
// DirectReducerTests.swift
@Test("updateMealEntry does not mutate state directly (handled by middleware)")
func updateMealEntryNoOp() {
    var state = AppState()
    let original = MealEntry(timestamp: Date(), mealDescription: "Old", carbsGrams: 30, analysisSessionId: nil)
    state.mealEntryValues = [original]
    let updated = MealEntry(id: original.id, timestamp: original.timestamp, mealDescription: "New", carbsGrams: 45, analysisSessionId: nil)
    directReducer(state: &state, action: .updateMealEntry(mealEntry: updated))
    // Reducer is a no-op; middleware persists and dispatches setMealEntryValues
    #expect(state.mealEntryValues == [original])
}

@Test("updateInsulinDelivery does not mutate state directly")
func updateInsulinDeliveryNoOp() {
    var state = AppState()
    let original = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
    state.insulinDeliveryValues = [original]
    let updated = InsulinDelivery(id: original.id, starts: original.starts, ends: original.ends, units: 5.0, type: original.type)
    directReducer(state: &state, action: .updateInsulinDelivery(insulinDelivery: updated))
    #expect(state.insulinDeliveryValues == [original])
}
```

- [ ] **Step 2: Run, expect FAIL** (action cases don't exist).

- [ ] **Step 3: Add the cases**

```swift
// Library/DirectAction.swift — alphabetical
case updateMealEntry(mealEntry: MealEntry)
case updateInsulinDelivery(insulinDelivery: InsulinDelivery)
```

```swift
// Library/DirectReducer.swift — inside the switch
case .updateMealEntry, .updateInsulinDelivery:
    break  // no-op; middleware persists and triggers .load*Values
```

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/DirectReducerTests.swift
git commit -m "feat: add update{Meal,Insulin} actions (reducer no-op; middleware-driven)"
```

---

### Task 8: Persist update actions via DataStore middleware

**Files:**
- Modify: `App/Modules/DataStore/MealStore.swift`
- Modify: `App/Modules/DataStore/InsulinDeliveryStore.swift`
- Modify: `App/Modules/DataStore/DataStore.swift` (add `updateMealEntry`, `updateInsulinDelivery`)

**Doc-review fixes:**
- File is `MealStore.swift`, not `MealEntryStore.swift`.
- Middleware dispatches `.loadMealEntryValues` (not phantom `setMealEntryValues(... fetchMealEntries() ...)`). The existing `.loadMealEntryValues` middleware case fetches from GRDB and dispatches `setMealEntryValues`.

- [ ] **Step 1: Add `.updateMealEntry` middleware case**

```swift
// MealStore.swift — inside mealEntryStoreMiddleware switch
case .updateMealEntry(mealEntry: let mealEntry):
    DataStore.shared.updateMealEntry(mealEntry)
    return Just(DirectAction.loadMealEntryValues)
        .setFailureType(to: DirectError.self)
        .eraseToAnyPublisher()
```

```swift
// DataStore.swift — extension or member
func updateMealEntry(_ value: MealEntry) {
    do {
        try dbQueue.write { db in
            try value.update(db)
        }
    } catch {
        DirectLog.error("updateMealEntry failed: \(error)")
    }
}
```

- [ ] **Step 2: Mirror for insulin**

```swift
// InsulinDeliveryStore.swift
case .updateInsulinDelivery(insulinDelivery: let insulin):
    DataStore.shared.updateInsulinDelivery(insulin)
    return Just(DirectAction.loadInsulinDeliveryValues)
        .setFailureType(to: DirectError.self)
        .eraseToAnyPublisher()
```

```swift
// DataStore.swift
func updateInsulinDelivery(_ value: InsulinDelivery) {
    do {
        try dbQueue.write { db in
            try value.update(db)
        }
    } catch {
        DirectLog.error("updateInsulinDelivery failed: \(error)")
    }
}
```

- [ ] **Step 3: Build, run, manually verify a CombinedEntryEditView save commits to GRDB and the chart re-renders with the new values after `loadMealEntryValues` returns.**

- [ ] **Step 4: Commit**

```bash
git add App/Modules/DataStore/MealStore.swift App/Modules/DataStore/InsulinDeliveryStore.swift App/Modules/DataStore/DataStore.swift
git commit -m "feat: persist update{Meal,Insulin} via GRDB + load-after-write pattern"
```

---

## Phase 5 — AddInsulinView rewrite (D4 standalone path)

### Task 9: Replace Picker + DatePicker with AmberChip + StepperField + QuickTimeChips, preserve callback contract

**Files:**
- Modify: `App/Views/AddViews/AddInsulinView.swift`
- Modify: `App/Views/OverviewView.swift` (call site adds `editingDelivery: nil`)

**Doc-review fixes:**
- Preserve the existing `addCallback: (Date, Date, Double, InsulinType) -> Void` and `currentIOB: Double?` parameters.
- Add new optional `editingDelivery: InsulinDelivery? = nil`.
- Add destructive Delete button when `editingDelivery != nil`.
- Time control here uses `QuickTimeChips` (not DatePicker) per spec — most uses are new entries near "now".

- [ ] **Step 1: Rewrite the Form body** (use the v1 plan Task 11 body verbatim — it was correct in shape; just confirm the existing `addCallback` is invoked from `save()` and the new Delete button dispatches `.deleteInsulinDelivery` only when `editingDelivery != nil`).

- [ ] **Step 2: Update OverviewView's call site to pass `editingDelivery: nil`** (and check for any other call site via `grep -rn "AddInsulinView(" App/`).

- [ ] **Step 3: Build, run, smoke-test sticky [INSULIN] button.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/AddInsulinView.swift App/Views/OverviewView.swift
git commit -m "feat: AddInsulinView uses AmberChip + StepperField + QuickTimeChips"
```

---

## Phase 6 — Adapt EventMarkerLaneView (D1)

### Task 10: Bare-icon visual + onTapGroup callback

**Files:**
- Modify: `App/Views/Overview/EventMarkerLaneView.swift`
- Modify: `App/Views/Overview/ChartView.swift` (lines 86–108 — pass the new callback)

**D1 visual changes:**
- Drop chip background + border (`.background(Color.black.opacity(0.6))`, `.cornerRadius(3)`, `.overlay(... RoundedRectangle.stroke ...)`)
- Drop the per-marker `Text(marker.label)` (counts/grams/units now live in the list overlay, not on the chart)
- Increase icon size to 22pt (from 10pt)
- Stack consolidated icons vertically (insulin top → food middle → exercise bottom) with a small badge for count

**API change:** Add `onTapGroup: (ConsolidatedMarkerGroup) -> Void` parallel to existing `onTapMeal`/`onTapInsulin`. Today's path (single-meal/single-insulin direct tap) routes through `onTapGroup` for the unified flow, so we replace `tapSingleMarker(_:)` with a single `onTapGroup(group)` invocation. Keep the legacy callbacks behind a transitional flag — but we delete them in Task 12 once the new flow is wired.

- [ ] **Step 1: Update `EventMarkerLaneView` body**

```swift
// EventMarkerLaneView.swift — replace markerView body and tapSingleMarker
struct EventMarkerLaneView: View {
    let markerGroups: [ConsolidatedMarkerGroup]
    let totalWidth: CGFloat
    let timeRange: ClosedRange<Date>
    let scoredMealEntryIds: Set<UUID>
    let onTapGroup: (ConsolidatedMarkerGroup) -> Void   // ← new

    private let laneHeight: CGFloat = 48               // 48pt for 88×48 touch target
    private let iconSize: CGFloat = 22

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(markerGroups) { group in
                markerView(for: group)
                    .position(x: xPosition(for: group.time), y: laneHeight / 2)
                    .frame(width: 88, height: 48)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapGroup(group) }
                    .accessibilityLabel(accessibilityLabel(for: group))
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: laneHeight)
    }

    @ViewBuilder
    private func markerView(for group: ConsolidatedMarkerGroup) -> some View {
        if group.isSingle, let marker = group.markers.first {
            Image(systemName: marker.type.icon)
                .font(.system(size: iconSize))
                .foregroundStyle(marker.type.color)
                .overlay(scoredMealCue(for: group), alignment: .bottomTrailing)
        } else {
            ZStack {
                ForEach(Array(group.markers.sorted(by: stackOrder).prefix(3).enumerated()), id: \.offset) { idx, marker in
                    Image(systemName: marker.type.icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(marker.type.color)
                        .offset(y: CGFloat(idx) * -3)
                }
                Text("\(group.markers.count)")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(group.dominantType.color))
                    .offset(x: 14, y: 12)
            }
        }
    }

    private func stackOrder(_ a: EventMarker, _ b: EventMarker) -> Bool {
        priority(a.type) < priority(b.type)
    }
    private func priority(_ t: EventMarkerType) -> Int {
        switch t { case .bolus: return 0; case .meal: return 1; case .exercise: return 2 }
    }

    @ViewBuilder
    private func scoredMealCue(for group: ConsolidatedMarkerGroup) -> some View {
        if group.isSingle, group.markers[0].type == .meal,
           scoredMealEntryIds.contains(group.markers[0].sourceID) {
            Circle().fill(AmberTheme.amber).frame(width: 4, height: 4)
        }
    }

    private func accessibilityLabel(for group: ConsolidatedMarkerGroup) -> String {
        if group.isSingle, let m = group.markers.first {
            switch m.type {
            case .meal: return "Meal at \(m.time.toLocalTime())"
            case .bolus: return "Insulin at \(m.time.toLocalTime())"
            case .exercise: return "Exercise at \(m.time.toLocalTime())"
            }
        }
        return "\(group.markers.count) entries at \(group.time.toLocalTime())"
    }

    private func xPosition(for time: Date) -> CGFloat {
        // unchanged from existing
        let totalDuration = timeRange.upperBound.timeIntervalSince(timeRange.lowerBound)
        guard totalDuration > 0 else { return 0 }
        let offset = time.timeIntervalSince(timeRange.lowerBound)
        return (offset / totalDuration) * totalWidth
    }
}
```

Note: this drops the in-lane `expandedGroupID` panel (today's expanded inline detail). The new flow opens the list overlay sheet instead, so no inline panel is needed.

- [ ] **Step 2: Build (will not yet integrate; that's Task 12)**

- [ ] **Step 3: Commit**

```bash
git add App/Views/Overview/EventMarkerLaneView.swift
git commit -m "refactor: EventMarkerLaneView bare-icon visual + onTapGroup callback"
```

---

## Phase 7 — EntryGroupListOverlay (D2)

### Task 11: List overlay with rich sub-lines (IN PROGRESS, confounders, PersonalFood, IOB, mmol/L)

**Files:**
- Create: `App/Views/Overview/MealOverlayLogic.swift` (extracted from ChartView's existing `computeMealOverlayDelta` + `detectMealConfounders`)
- Create: `App/Views/Overview/EntryGroupListOverlay.swift`
- Create/modify: `DOSBTSTests/EntryGroupListOverlayTests.swift`

**Doc-review restorations:** keep IN PROGRESS state, confounder icons, PersonalFood glycemic average, mmol/L formatting from today's `activeMealOverlay`.

- [ ] **Step 1: Extract `computeMealOverlayDelta` + `detectMealConfounders` from `ChartView.swift` (~lines 1415–end of those helpers) into `App/Views/Overview/MealOverlayLogic.swift` as free functions taking explicit parameters (no `self` reference).**

(The functions stay; just relocate them so `EntryGroupListOverlay` can call them without depending on `ChartView`.)

- [ ] **Step 2: Write failing tests for sub-line text generation**

```swift
// EntryGroupListOverlayTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("EntryGroupListOverlay sub-lines")
struct EntryGroupListOverlayTests {
    @Test("meal sub-line shows IN PROGRESS within 2-hour window")
    func mealInProgress() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-30 * 60), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: nil)
        let line = EntryGroupListOverlay.subline(for: .meal(m), itemCount: 3, mealImpact: nil, personalFoodAvg: nil, glucoseUnit: .mgdl, iob: nil, paired: false, mealStart: nil, confounders: [])
        #expect(line.contains("IN PROGRESS"))
    }

    @Test("meal sub-line shows mmol/L delta when unit is mmol")
    func mealMmol() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-3 * 3600), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: nil)
        let impact = MealImpact(mealEntryId: m.id, baselineGlucose: 117, peakGlucose: 189, deltaMgDL: 72, timeToPeakMinutes: 105, isClean: true, timestamp: m.timestamp)
        let line = EntryGroupListOverlay.subline(for: .meal(m), itemCount: 3, mealImpact: impact, personalFoodAvg: nil, glucoseUnit: .mmolL, iob: nil, paired: false, mealStart: nil, confounders: [])
        #expect(line.contains("4.0 mmol/L"))   // 72 / 18 = 4.0
    }

    @Test("meal sub-line includes PersonalFood avg with observation count when available")
    func mealPersonalFood() {
        let m = MealEntry(timestamp: Date().addingTimeInterval(-3 * 3600), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: UUID())
        let impact = MealImpact(mealEntryId: m.id, baselineGlucose: 117, peakGlucose: 189, deltaMgDL: 72, timeToPeakMinutes: 105, isClean: true, timestamp: m.timestamp)
        let line = EntryGroupListOverlay.subline(for: .meal(m), itemCount: 3, mealImpact: impact, personalFoodAvg: PersonalFoodGlycemic(avgDelta: 68, observationCount: 4), glucoseUnit: .mgdl, iob: nil, paired: false, mealStart: nil, confounders: [])
        #expect(line.contains("avg +68"))
        #expect(line.contains("(4)"))
    }
}
```

- [ ] **Step 3: Run, expect FAIL.**

- [ ] **Step 4: Implement `EntryGroupListOverlay`** — uses `ConsolidatedMarkerGroup` directly (no new `EntryGroup` type).

```swift
// EntryGroupListOverlay.swift
import SwiftUI

struct PersonalFoodGlycemic {
    let avgDelta: Int
    let observationCount: Int
}

struct EntryGroupListOverlay: View {
    let group: ConsolidatedMarkerGroup
    let mealEntries: [MealEntry]
    let insulinDeliveries: [InsulinDelivery]
    let exerciseEntries: [ExerciseEntry]
    let mealImpacts: [UUID: MealImpact]
    let personalFoodAvgs: [UUID: PersonalFoodGlycemic]
    let glucoseUnit: GlucoseUnit
    let iobAtTime: (Date) -> Double?
    let confoundersFor: (MealEntry) -> [ConfounderType]
    var onEdit: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        // Wrap in ScrollView for safety (large groups, accessibility text sizes)
        ScrollView {
            VStack(spacing: 0) {
                header
                Divider().background(AmberTheme.amberDark)
                ForEach(chronologicalRows, id: \.id) { marker in
                    row(for: marker)
                    Divider().background(AmberTheme.amberDark.opacity(0.4))
                }
            }
        }
        .safeAreaInset(edge: .bottom) { okBar }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var chronologicalRows: [EventMarker] {
        group.markers.sorted { $0.time < $1.time }
    }

    private var header: some View {
        HStack {
            Text(headerText)
                .font(DOSTypography.body)
                .foregroundStyle(AmberTheme.amber)
            Spacer()
            Button(action: onEdit) {
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                    Text("Edit").font(DOSTypography.caption)
                }
                .foregroundStyle(AmberTheme.amberLight)
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit this entry group")
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.sm)
    }

    private var headerText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm · 'Logged'"
        return f.string(from: group.time)
    }

    private var okBar: some View {
        Button(action: onDismiss) {
            Text("OK")
                .font(DOSTypography.button)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 2).fill(AmberTheme.amber))
        }
        .padding(DOSSpacing.md)
    }

    private func row(for marker: EventMarker) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: marker.type.icon)
                .foregroundStyle(marker.type.color)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText(for: marker))
                    .font(DOSTypography.body)
                    .foregroundStyle(AmberTheme.amber)
                Text(sublineText(for: marker))
                    .font(DOSTypography.caption)
                    .foregroundStyle(AmberTheme.amberDark)
            }
            Spacer()
            Text(valueText(for: marker))
                .font(DOSTypography.displayMedium)   // ← per spec line 265
                .foregroundStyle(marker.type.color)
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voiceOverLabel(for: marker))
    }

    // (primaryText, sublineText, valueText, voiceOverLabel — see static `subline(for:)` test entry point)
    // These delegate to a static helper for testability:
    static func subline(
        for marker: MarkerEntryStub,    // helper enum used only by tests
        itemCount: Int,
        mealImpact: MealImpact?,
        personalFoodAvg: PersonalFoodGlycemic?,
        glucoseUnit: GlucoseUnit,
        iob: Double?,
        paired: Bool,
        mealStart: Date?,
        confounders: [ConfounderType]
    ) -> String { /* implementation: see test expectations */ }
}
```

(Implementation detail: `MarkerEntryStub` is a test-only enum that wraps `MealEntry`/`InsulinDelivery`/`ExerciseEntry` so the static `subline(for:)` is unit-testable without a full overlay context. The instance methods `sublineText(for:)`/etc. inside the view delegate to `subline(for:)`.)

- [ ] **Step 5: Run, expect PASS.**

- [ ] **Step 6: Commit**

```bash
git add App/Views/Overview/MealOverlayLogic.swift App/Views/Overview/EntryGroupListOverlay.swift DOSBTSTests/EntryGroupListOverlayTests.swift
git commit -m "feat: EntryGroupListOverlay with IN PROGRESS, confounders, PersonalFood, mmol/L"
```

---

## Phase 8 — CombinedEntryEditView (D3)

### Task 12: Combined modal — id-preserving updates, hydrate from analysisSessionId, no auto-create

**Files:**
- Create: `App/Views/AddViews/CombinedEntryEditView.swift`

**Doc-review fixes:**
- Use id-preserving constructors: `MealEntry(id: original.id, timestamp:..., mealDescription:..., carbsGrams:..., analysisSessionId: original.analysisSessionId, proteinGrams: original.proteinGrams, fatGrams: original.fatGrams, calories: original.calories, fiberGrams: original.fiberGrams)`. Same pattern for `InsulinDelivery`.
- Remove auto-create from `save()`. Modal is edit-only.
- Hydrate multi-item: if `meal.analysisSessionId != nil`, fetch the original staging items from GRDB (`DataStore.shared.getAnalysisSessionItems(sessionId:)` — add this if it doesn't exist; otherwise show a banner "This meal was analyzed with N items; editing here updates the total only" and a link "Edit in food analysis").
- Wrap modal body in `ScrollView` so Dynamic Type ≥ xxxLarge / iPhone SE behaves gracefully. Document the no-scroll claim as default-Dynamic-Type only (not universal).
- Cancel-with-dirty: confirm-discard dialog before dismiss when `isDirty`.

- [ ] **Step 1: Implement the modal** — see v1 plan Tasks 15+16 for the section bodies, but apply these corrections in `save()`:

```swift
// CombinedEntryEditView.save()
private func save() {
    if let original = originalMealEntry, hasMealEdits {
        let updated = MealEntry(
            id: original.id,
            timestamp: time,
            mealDescription: description.isEmpty ? original.mealDescription : description,
            carbsGrams: stagedItems.reduce(0) { $0 + $1.carbsG },
            analysisSessionId: original.analysisSessionId,
            proteinGrams: original.proteinGrams,
            fatGrams: original.fatGrams,
            calories: original.calories,
            fiberGrams: original.fiberGrams
        )
        store.dispatch(.updateMealEntry(mealEntry: updated))
    }
    if let original = originalInsulinDelivery, hasInsulinEdits, let u = units, u > 0 {
        let updated = InsulinDelivery(
            id: original.id,
            starts: time,
            ends: insulinType == .basal ? endsTime : time,
            units: u,
            type: insulinType
        )
        store.dispatch(.updateInsulinDelivery(insulinDelivery: updated))
    }
    // No auto-create. Empty companion section + Save = no-op for that section.
    // Delete-via-empty: if user explicitly cleared a section that was originally populated, dispatch delete:
    if let original = originalMealEntry, stagedItems.allSatisfy({ $0.carbsG == 0 && $0.name.isEmpty }) {
        store.dispatch(.deleteMealEntry(mealEntry: original))
    }
    if let original = originalInsulinDelivery, units == nil || (units ?? 0) == 0 {
        store.dispatch(.deleteInsulinDelivery(insulinDelivery: original))
    }
    dismiss()
}

private func cancel() {
    if isDirty {
        showDiscardConfirm = true
    } else {
        dismiss()
    }
}
```

- [ ] **Step 2: Build, run, manual-verify with the smoke matrix in Task 14.**

- [ ] **Step 3: Commit**

```bash
git add App/Views/AddViews/CombinedEntryEditView.swift
git commit -m "feat: CombinedEntryEditView with id-preserving constructors + edit-only semantics"
```

---

## Phase 9 — ChartView integration

### Task 13: Wire EventMarkerLaneView's onTapGroup, drop sibling sheets and old overlays

**Files:**
- Modify: `App/Views/Overview/ChartView.swift`
- Modify: `App/Views/OverviewView.swift`

**Doc-review fixes:**
- Pass an `onTapGroup` closure from `OverviewView` → `ChartView` → `EventMarkerLaneView`. No Redux round-trip; no `setSelectedEntryGroup` action.
- Delete `.sheet(item: $tappedMealEntry)` (~lines 198–214) and `.sheet(item: $tappedMealGroup)` (~lines 227–286).
- Delete `.confirmationDialog` for `tappedInsulinEntry` (~line 215).
- Delete `activeMealOverlay` inline card (~lines 575–680).
- Delete the corresponding `@State` properties.
- Add `onTapGroup` parameter to `ChartView` so `OverviewView` can wire `activeSheet = .entryGroupReadOverlay(group)`.

- [ ] **Step 1: Add the two new ActiveSheet cases to OverviewView**

```swift
// OverviewView.swift
private enum ActiveSheet: Identifiable {
    case insulin
    case meal
    case bloodGlucose
    case treatmentModal(alarmFiredAt: Date)
    case filteredFoodEntry
    case treatmentRecheck(glucoseValue: Int)
    case entryGroupReadOverlay(ConsolidatedMarkerGroup)
    case combinedEntryEdit(ConsolidatedMarkerGroup)

    var id: String {
        switch self {
        // existing
        case .insulin: return "insulin"
        case .meal: return "meal"
        case .bloodGlucose: return "bloodGlucose"
        case .treatmentModal: return "treatmentModal"
        case .filteredFoodEntry: return "filteredFoodEntry"
        case .treatmentRecheck: return "treatmentRecheck"
        case .entryGroupReadOverlay(let g): return "entryGroupReadOverlay-\(g.id)"
        case .combinedEntryEdit(let g): return "combinedEntryEdit-\(g.id)"
        }
    }
}
```

- [ ] **Step 2: Add sheet bodies**

```swift
// OverviewView.swift — sheet ViewBuilder
case .entryGroupReadOverlay(let group):
    EntryGroupListOverlay(
        group: group,
        mealEntries: store.state.mealEntryValues,
        insulinDeliveries: store.state.insulinDeliveryValues,
        exerciseEntries: store.state.exerciseEntryValues,
        mealImpacts: store.state.mealImpactValuesById,    // see Step 4 — needs new state property
        personalFoodAvgs: store.state.personalFoodAvgsById, // ditto
        glucoseUnit: store.state.glucoseUnit,
        iobAtTime: { date in
            IOBCalculator.computeIOB(
                deliveries: store.state.iobDeliveries,
                bolusModel: store.state.insulinPreset,
                basalDIA: store.state.basalDIA,
                at: date
            )
        },
        confoundersFor: { meal in
            MealOverlayLogic.detectConfounders(
                meal: meal,
                insulins: store.state.insulinDeliveryValues,
                exercises: store.state.exerciseEntryValues
            )
        },
        onEdit: {
            pendingSheet = .combinedEntryEdit(group)
            activeSheet = nil
        },
        onDismiss: { activeSheet = nil }
    )

case .combinedEntryEdit(let group):
    CombinedEntryEditView(originalGroup: group)
        .environmentObject(store)
```

- [ ] **Step 3: Pass the tap callback into ChartView**

```swift
// OverviewView.swift — where ChartView is mounted
ChartView(onTapMarkerGroup: { group in
    activeSheet = .entryGroupReadOverlay(group)
})
```

```swift
// ChartView.swift — body, EventMarkerLaneView mount
EventMarkerLaneView(
    markerGroups: markerGroups,
    totalWidth: chartWidth,
    timeRange: chartStartDate...chartEndDate,
    scoredMealEntryIds: store.state.scoredMealEntryIds,
    onTapGroup: onTapMarkerGroup
)
```

- [ ] **Step 4: Add `mealImpactValuesById` and `personalFoodAvgsById` state properties (and a small middleware to populate them on `.setAppState(.active)` and after meal edits)**

Add to `DirectState.swift` + `AppState.swift`:
```swift
var mealImpactValuesById: [UUID: MealImpact] { get set }
var personalFoodAvgsById: [UUID: PersonalFoodGlycemic] { get set }
```

Add `case setMealImpactValuesById(...)` and `setPersonalFoodAvgsById(...)` actions + reducer cases.

Add a small middleware (`App/Modules/MealImpact/MealImpactStore.swift` — extend the existing one) to fetch and dispatch on `.setAppState(.active)` and after `.updateMealEntry`/`.deleteMealEntry`/`.addMealEntry`.

- [ ] **Step 5: Delete the obsolete ChartView state + sheets + overlay**

```swift
// ChartView.swift — remove these
@State private var tappedInsulinEntry: InsulinDelivery? = nil
@State private var tappedMealEntry: MealEntry? = nil
@State private var tappedMealGroup: ConsolidatedMarkerGroup? = nil
@State private var activeMealOverlay: MealEntry? = nil
// remove the .confirmationDialog at ~line 215
// remove the .sheet(item: $tappedMealEntry) at ~lines 198–214
// remove the .sheet(item: $tappedMealGroup) at ~lines 227–286
// remove the `if let overlayMeal = activeMealOverlay {...}` block at ~lines 575–680
```

- [ ] **Step 6: Build + smoke-test**

Confirm: tap meal marker → list overlay; tap insulin marker → list overlay; tap cross-type cluster → list overlay with chronological rows; tap Edit → sheet swap to combined modal.

- [ ] **Step 7: Commit**

```bash
git add Library/DirectAction.swift Library/DirectState.swift Library/DirectReducer.swift App/AppState.swift App/Modules/MealImpact/MealImpactStore.swift App/Views/OverviewView.swift App/Views/Overview/ChartView.swift
git commit -m "feat: ChartView routes marker taps to EntryGroupListOverlay (closure callback)"
```

---

## Phase 10 — D8 delete affordance moves + final smoke

### Task 14: Smoke test + CHANGELOG

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```

Expected: all tests pass.

- [ ] **Step 2: Manual smoke matrix**

For each, on iPhone 17 Pro and iPhone SE simulators:

1. Tap single meal marker → list overlay shows 1 row with IN PROGRESS / delta / PersonalFood avg sub-line + OK
2. Tap single insulin marker → list overlay shows 1 row with IOB sub-line + OK (no Delete dialog)
3. Tap cross-type cluster → list overlay shows N rows in chronological order
4. Tap Edit on any group → combined modal with appropriate sections populated
5. In combined modal, expand one row, change Amount → carbs auto-scale; type manual carbs → `manual` indicator
6. Expand a second row → first row collapses (accordion)
7. Cancel with dirty edits → confirm-discard sheet
8. Save → chart re-renders with updated values, sheet dismisses, GRDB persists
9. Standalone `AddInsulinView` (sticky [INSULIN] button) → chip row + stepper + chips, Delete with confirmation visible only when editing existing dose
10. `FoodPhotoAnalysisView` (sticky [MEAL] → photo) → all 8 sections present (Nutrition, Portion, Description, Items, Clarify, Confidence, Disclaimer, Log Meal), barcode rescan still pushes scanner and preserves staged items
11. mmol/L user: list overlay shows mmol values (e.g. 4.0 mmol/L not 72 mg/dL)

- [ ] **Step 3: Append CHANGELOG entry**

```markdown
### Added
- Unified marker → read overlay → edit flow (DMNC-848). Tapping any chart marker opens a Libre-style list overlay with chronological rows + IN PROGRESS state, confounder icons, PersonalFood glycemic average, and IOB-at-dose-time. Edit opens a single combined modal with shared time and edit-only semantics.
- AmberChip, StepperField, QuickTimeChips design-system primitives.
- StagingPlateRowView extraction (shared between FoodPhotoAnalysisView and CombinedEntryEditView).

### Changed
- AddInsulinView replaces Picker with chip row + stepper + quick-time chips.
- Insulin marker tap no longer shows a bare Delete dialog; delete now requires entering Edit.
- Chart marker visual: bare type-coloured icons replace bordered chips. Cross-type clusters consolidate with stacked icons and a count badge.
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog — DMNC-848 unified marker + entry experience"
```

---

## Self-review

- [ ] **Spec coverage:**
  - D1 (markers): Task 10 (EventMarkerLaneView visual + onTapGroup) ✓
  - D2 (list overlay): Tasks 11, 13 ✓
  - D3 (combined modal): Tasks 7, 8, 12 ✓
  - D4 (primitives): Tasks 1, 2, 3, 9 ✓
  - D5 (StagingPlateRowView): Tasks 4, 5 ✓
  - D8 (delete moves): Tasks 9 (standalone Delete button), 12 (delete-via-empty in combined modal) ✓
  - Sheet plumbing (no nested): Task 13 (uses existing `pendingSheet`/`onDismiss`) ✓
  - Migration (no GRDB schema changes): Tasks 7, 8 (upserts via `update(db)`) ✓

- [ ] **Type-name + API-name consistency check:**
  - All references use real names: `ExerciseEntry.startTime`/`activityType`, `MealStore.swift`, `directReducer(state:action:)`, `AppState()` no-arg, `InsulinType.allCases` (after Task 0a), `EditableFoodItem` (after hoist), `ConsolidatedMarkerGroup` + `EventMarker` + `EventMarkerType` (after promotion in 0d).
  - Id-preserving constructors used in Tasks 7, 12 saves.
  - Middleware uses `.load*Values` (not phantom `fetch*`).

- [ ] **No phantom symbols:** plan does not reference `activeIOB`, `mealImpactValues` (uses `mealImpactValuesById`), `xCoordinate(for:)`, `visibleMeals`, `visibleInsulins`, `visibleExercises`, `setSelectedEntryGroup`, or `MarkerLaneView`.
