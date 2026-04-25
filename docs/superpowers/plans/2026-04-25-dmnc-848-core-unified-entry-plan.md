# DMNC-848 Core Unified Entry Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the chart's separate per-type marker handling and the bare-`confirmationDialog` insulin tap with a unified Libre-style list overlay → combined edit modal flow, and ship the shared design-system primitives that back it.

**Architecture:** New `MarkerLaneView` resolves cross-type marker hits into an `EntryGroup` value object. Group → `EntryGroupListOverlay` (sheet, read-only, shared timestamp + chronological rows). Edit handoff via `pendingSheet`/`onDismiss` (no nested sheets per CLAUDE.md) → `CombinedEntryEditView` (Cancel + Save, FOOD section with extracted `StagingPlateRowView`, INSULIN section with new `AmberChip` + `StepperField` + `QuickTimeChips`, shared compact `DatePicker`).

**Tech Stack:** SwiftUI, SwiftUI Charts, Combine, Redux-like Store (`DirectStore`), GRDB (existing middleware), Swift Testing for unit tests, XCTest target `DOSBTSTests`.

**Spec:** `docs/brainstorms/2026-04-25-unified-entry-and-chart-markers-design.md` (D1, D2, D3, D4, D5, D8).

**Out of scope (separate plans):** D6 HR overlay, D7 strict-separation toggle.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `Library/DesignSystem/Components/AmberChip.swift` | Type-coloured chip primitive (`.type`, `.preset` variants). Both targets. |
| `App/DesignSystem/Components/StepperField.swift` | `[−] value [+]` numeric stepper with tap-to-type. App only. |
| `App/DesignSystem/Components/QuickTimeChips.swift` | Chip row of `AmberChip(.preset)` with `⋯` → DatePicker popover. App only. |
| `App/Views/AddViews/Components/StagingPlateRowView.swift` | Collapsed-summary + expanded-edit row used by both food entry surfaces. |
| `Library/Content/MarkerEntry.swift` | Sum type (Meal / Insulin / Exercise) + `MarkerEntryProtocol`. |
| `Library/Content/EntryGroup.swift` | Value type wrapping `[MarkerEntry]` at a single timegroup. |
| `Library/Content/InsulinImpact.swift` | View-layer computed type (no GRDB). |
| `App/Views/Overview/MarkerLaneView.swift` | Cross-type marker rendering + hit testing for the chart. |
| `App/Views/Overview/EntryGroupListOverlay.swift` | Libre-style list read surface (D2). |
| `App/Views/AddViews/CombinedEntryEditView.swift` | Stacked-sections edit modal (D3). |
| `DOSBTSTests/EntryGroupTests.swift` | EntryGroup grouping + chronological ordering. |
| `DOSBTSTests/InsulinImpactTests.swift` | InsulinImpact computation. |
| `DOSBTSTests/StagingPlateRowTests.swift` | Ratio auto-scale + manual override logic. |

### Modified files

| Path | Change |
|---|---|
| `Library/DirectAction.swift` | Add `updateMealEntry(MealEntry)`, `updateInsulinDelivery(InsulinDelivery)`. |
| `Library/DirectReducer.swift` | Handle the two new update actions (upsert by id). |
| `App/Modules/DataStore/MealEntryStore.swift` | Persist `updateMealEntry`. |
| `App/Modules/DataStore/InsulinDeliveryStore.swift` | Persist `updateInsulinDelivery`. |
| `App/Views/AddViews/AddInsulinView.swift` | Replace `Picker("Type")` with `AmberChip(.type)` row; replace value entry with `StepperField`; replace start-date with `QuickTimeChips`; add destructive Delete button below Save. |
| `App/Views/AddViews/FoodPhotoAnalysisView.swift` | Replace inline expandable item rows with `StagingPlateRowView` instances. |
| `App/Views/Overview/ChartView.swift` | Drop in-chart `tappedInsulinEntry` confirmDialog; drop `activeMealOverlay` inline card; mount `MarkerLaneView`; sheet plumbing for `entryGroupReadOverlay` and `combinedEntryEdit` cases. |
| `App/Views/OverviewView.swift` | Add `.entryGroupReadOverlay(EntryGroup)` and `.combinedEntryEdit(EntryGroup)` to `ActiveSheet` enum + sheet body. |
| `DOSBTSTests/DirectReducerTests.swift` | Cover the two new update actions. |

---

## Phase 1 — Design system primitives (D4)

### Task 1: AmberChip primitive

**Files:**
- Create: `Library/DesignSystem/Components/AmberChip.swift`
- Create: `DOSBTSTests/AmberChipTests.swift`

- [ ] **Step 1: Write the failing test for selection state**

```swift
// DOSBTSTests/AmberChipTests.swift
import Testing
import SwiftUI
@testable import DOSBTSApp

@Suite("AmberChip")
struct AmberChipTests {
    @Test("type variant exposes selected state through binding")
    func typeVariantSelectionState() {
        var selected: InsulinType = .mealBolus
        let binding = Binding(get: { selected }, set: { selected = $0 })
        let chip = AmberChip(label: "MEAL", isSelected: binding.wrappedValue == .mealBolus)
        #expect(chip.isSelected == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

`xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:DOSBTSTests/AmberChipTests`
Expected: FAIL with "cannot find 'AmberChip' in scope".

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
        action: @escaping () -> Void = {}
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
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Same xcodebuild command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Library/DesignSystem/Components/AmberChip.swift DOSBTSTests/AmberChipTests.swift
git commit -m "feat: add AmberChip design system primitive"
```

Note: also add `AmberChipTests.swift` to `DOSBTSTests` group + `PBXSourcesBuildPhase` in `project.pbxproj` (tests aren't auto-synced per CLAUDE.md).

---

### Task 2: StepperField primitive

**Files:**
- Create: `App/DesignSystem/Components/StepperField.swift`
- Create: `DOSBTSTests/StepperFieldTests.swift`

- [ ] **Step 1: Write the failing test for clamping**

```swift
// DOSBTSTests/StepperFieldTests.swift
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
        #expect(v == 50.0)  // clamped
    }

    @Test("decrementing past lower bound clamps and treats nil as 0")
    func clampsDown() {
        var v: Double? = nil
        StepperField.decrement(&v, step: 0.5, range: 0...50)
        #expect(v == 0.0)  // nil treated as 0
    }
}
```

- [ ] **Step 2: Run test, expect FAIL** (`StepperField` not in scope).

- [ ] **Step 3: Implement `StepperField`**

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
        .background(
            RoundedRectangle(cornerRadius: 2).fill(Color.black)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2).stroke(AmberTheme.amberDark, lineWidth: 1)
        )
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
- Create: `DOSBTSTests/QuickTimeChipsTests.swift`

- [ ] **Step 1: Write the failing test for preset offset application**

```swift
// DOSBTSTests/QuickTimeChipsTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("QuickTimeChips")
struct QuickTimeChipsTests {
    @Test("applying −15m preset subtracts 15 minutes from now")
    func minus15() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        let result = QuickTimeChips.applyPreset(.minus(15), anchor: anchor)
        #expect(result.timeIntervalSince(anchor) == -900)
    }

    @Test(".now resets to anchor")
    func now() {
        let anchor = Date(timeIntervalSince1970: 1_777_000_000)
        let result = QuickTimeChips.applyPreset(.now, anchor: anchor)
        #expect(result == anchor)
    }
}
```

- [ ] **Step 2: Run test, expect FAIL.**

- [ ] **Step 3: Implement `QuickTimeChips`**

```swift
// App/DesignSystem/Components/QuickTimeChips.swift
import SwiftUI

enum TimeOffset: Hashable {
    case now
    case minus(Int)  // minutes

    var label: String {
        switch self {
        case .now: return "NOW"
        case .minus(let m): return m < 60 ? "−\(m)m" : "−\(m / 60)h"
        }
    }
}

struct QuickTimeChips: View {
    let title: String
    @Binding var date: Date
    var presets: [TimeOffset] = [.now, .minus(15), .minus(30), .minus(60)]

    @State private var showCustomPicker: Bool = false
    @State private var anchorDate: Date = Date()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(presets, id: \.self) { preset in
                AmberChip(
                    label: preset.label,
                    variant: .preset,
                    tint: AmberTheme.amber,
                    isSelected: matches(preset),
                    action: { date = Self.applyPreset(preset, anchor: anchorDate) }
                )
            }
            AmberChip(
                label: "⋯",
                variant: .preset,
                tint: AmberTheme.amber,
                isSelected: showCustomPicker,
                action: { showCustomPicker.toggle() }
            )
            .popover(isPresented: $showCustomPicker) {
                DatePicker(title, selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
            }
        }
        .onAppear { anchorDate = Date() }
    }

    private func matches(_ preset: TimeOffset) -> Bool {
        let target = Self.applyPreset(preset, anchor: anchorDate)
        return abs(date.timeIntervalSince(target)) < 30
    }

    static func applyPreset(_ preset: TimeOffset, anchor: Date) -> Date {
        switch preset {
        case .now: return anchor
        case .minus(let minutes): return anchor.addingTimeInterval(TimeInterval(-minutes * 60))
        }
    }
}
```

- [ ] **Step 4: Run test, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add App/DesignSystem/Components/QuickTimeChips.swift DOSBTSTests/QuickTimeChipsTests.swift
git commit -m "feat: add QuickTimeChips primitive with preset + custom popover"
```

---

## Phase 2 — StagingPlateRowView extraction (D5)

### Task 4: Extract StagingPlateRowView with ratio-link logic

**Files:**
- Create: `App/Views/AddViews/Components/StagingPlateRowView.swift`
- Create: `DOSBTSTests/StagingPlateRowTests.swift`

- [ ] **Step 1: Write failing tests for ratio-link auto-scale + manual override**

```swift
// DOSBTSTests/StagingPlateRowTests.swift
import Testing
@testable import DOSBTSApp

@Suite("StagingPlateRow ratio link")
struct StagingPlateRowTests {
    @Test("amount change auto-scales carbs proportionally when ratio set")
    func autoScale() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 22.5, currentAmountG: 60, baseServingG: 60, carbsPerG: 0.375)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 120)
        #expect(item.currentAmountG == 120)
        #expect(item.carbsG == 45.0)
    }

    @Test("manual carb edit that breaks ratio sets carbsPerG to nil")
    func manualOverride() {
        var item = EditableFoodItem(name: "Cheerios", carbsG: 45, currentAmountG: 120, baseServingG: 60, carbsPerG: 0.375)
        StagingPlateRowLogic.applyCarbsChange(item: &item, newCarbs: 50)
        #expect(item.carbsG == 50)
        #expect(item.carbsPerG == nil)  // ratio broken
    }

    @Test("amount over 10000 clamps")
    func clampsLargeAmount() {
        var item = EditableFoodItem(name: "Test", carbsG: 0, currentAmountG: 100, baseServingG: 100, carbsPerG: 0.5)
        StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: 50000)
        #expect(item.currentAmountG == 10000)
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement view + logic**

```swift
// App/Views/AddViews/Components/StagingPlateRowView.swift
import SwiftUI

enum StagingPlateRowLogic {
    static func applyAmountChange(item: inout EditableFoodItem, newAmount: Double) {
        let clamped = min(max(newAmount, 0), 10000)
        item.currentAmountG = clamped
        if let ratio = item.carbsPerG {
            item.carbsG = ratio * clamped
        }
    }

    static func applyCarbsChange(item: inout EditableFoodItem, newCarbs: Double) {
        item.carbsG = newCarbs
        if let ratio = item.carbsPerG, let amt = item.currentAmountG {
            let expected = ratio * amt
            if abs(newCarbs - expected) > 0.5 {
                item.carbsPerG = nil
            }
        }
    }

    static func summary(for item: EditableFoodItem) -> String {
        if let amt = item.currentAmountG {
            return "\(Int(amt))g · \(Int(item.carbsG))g C"
        }
        return "\(Int(item.carbsG))g C"
    }
}

struct StagingPlateRowView: View {
    @Binding var item: EditableFoodItem
    var onBarcodeRescan: (UUID) -> Void = { _ in }
    var isExpanded: Bool
    var onToggleExpand: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            collapsedHeader
            if isExpanded { expandedFields }
        }
    }

    private var collapsedHeader: some View {
        HStack {
            Text(item.name.isEmpty ? "New item" : item.name)
                .font(DOSTypography.body)
                .foregroundStyle(item.name.isEmpty ? AmberTheme.amberDark : AmberTheme.amber)
            Spacer()
            Text(StagingPlateRowLogic.summary(for: item))
                .font(DOSTypography.caption)
                .foregroundStyle(AmberTheme.amber)
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(DOSTypography.caption)
                .foregroundStyle(AmberTheme.amberDark)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.linear(duration: 0.18)) { onToggleExpand() } }
    }

    @ViewBuilder
    private var expandedFields: some View {
        VStack(spacing: DOSSpacing.sm) {
            HStack {
                Text("Name").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                TextField("Food name", text: $item.name)
                    .multilineTextAlignment(.trailing)
                    .focused($isNameFocused)
                Button { onBarcodeRescan(item.id) } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(AmberTheme.amberDark)
                }
                .buttonStyle(.plain)
            }
            if item.currentAmountG != nil {
                HStack {
                    Text("Amount").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                    TextField("0", value: $item.currentAmountG, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: item.currentAmountG) { _, new in
                            guard let new else { return }
                            StagingPlateRowLogic.applyAmountChange(item: &item, newAmount: new)
                        }
                    Text("g").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                }
            }
            HStack {
                Text("Carbs").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                TextField("0", value: $item.carbsG, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .onChange(of: item.carbsG) { _, new in
                        StagingPlateRowLogic.applyCarbsChange(item: &item, newCarbs: new)
                    }
                Text("g").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                if item.carbsPerG == nil && item.currentAmountG != nil {
                    Text("manual")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
            }
        }
        .padding(.leading, DOSSpacing.md)
    }
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add App/Views/AddViews/Components/StagingPlateRowView.swift DOSBTSTests/StagingPlateRowTests.swift
git commit -m "feat: extract StagingPlateRowView with ratio-link auto-scale"
```

---

### Task 5: Migrate FoodPhotoAnalysisView to use StagingPlateRowView

**Files:**
- Modify: `App/Views/AddViews/FoodPhotoAnalysisView.swift:410-540` (the food items section)

- [ ] **Step 1: Replace the inline `ForEach($stagedItems)` rendering with `StagingPlateRowView`**

Locate the food items `Section` (currently lines 410–550). Replace the `ForEach($stagedItems) { $item in VStack { ... } }` body with:

```swift
ForEach($stagedItems) { $item in
    StagingPlateRowView(
        item: $item,
        onBarcodeRescan: { itemID in
            scanTargetIndex = stagedItems.firstIndex(where: { $0.id == itemID })
        },
        isExpanded: item.isExpanded,
        onToggleExpand: { item.isExpanded.toggle() }
    )
}
.onDelete { offsets in
    focusedItemID = nil
    stagedItems.remove(atOffsets: offsets)
}
```

Keep the `Add Item` button below as it is.

- [ ] **Step 2: Build the app and confirm no build errors**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Run the app, take a photo / use favourite to populate the plate, expand a row, change Amount, verify carbs auto-scale; type a manual carb value, verify `manual` indicator appears**

Verification is manual — no automated test for the UI integration here. Accordion behaviour does NOT yet apply in this view (multiple rows can still expand simultaneously); accordion is added only to `CombinedEntryEditView` in Task 16.

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/FoodPhotoAnalysisView.swift
git commit -m "refactor: FoodPhotoAnalysisView uses StagingPlateRowView"
```

---

## Phase 3 — Domain types

### Task 6: MarkerEntry sum type

**Files:**
- Create: `Library/Content/MarkerEntry.swift`
- Create: `DOSBTSTests/MarkerEntryTests.swift`

- [ ] **Step 1: Write failing tests for marker dispatch**

```swift
// DOSBTSTests/MarkerEntryTests.swift
import Testing
import SwiftUI
@testable import DOSBTSApp

@Suite("MarkerEntry")
struct MarkerEntryTests {
    @Test("meal marker uses fork.knife icon and amber tint")
    func mealMarker() {
        let meal = MealEntry(timestamp: Date(), mealDescription: "Pasta", carbsGrams: 45, analysisSessionId: nil)
        let entry = MarkerEntry.meal(meal)
        #expect(entry.markerIcon == "fork.knife")
        #expect(entry.markerColor == AmberTheme.amber)
    }

    @Test("insulin marker uses syringe.fill icon and amberLight tint")
    func insulinMarker() {
        let insulin = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
        let entry = MarkerEntry.insulin(insulin)
        #expect(entry.markerIcon == "syringe.fill")
        #expect(entry.markerColor == AmberTheme.amberLight)
    }

    @Test("entry timestamp returns the underlying entry's start time")
    func timestampDispatch() {
        let now = Date()
        let meal = MealEntry(timestamp: now, mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        #expect(MarkerEntry.meal(meal).timestamp == now)
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement `MarkerEntry`**

```swift
// Library/Content/MarkerEntry.swift
import SwiftUI

enum MarkerEntry: Identifiable {
    case meal(MealEntry)
    case insulin(InsulinDelivery)
    case exercise(ExerciseEntry)

    var id: UUID {
        switch self {
        case .meal(let m): return m.id
        case .insulin(let i): return i.id
        case .exercise(let e): return e.id
        }
    }

    var timestamp: Date {
        switch self {
        case .meal(let m): return m.timestamp
        case .insulin(let i): return i.starts
        case .exercise(let e): return e.startDate
        }
    }

    var markerIcon: String {
        switch self {
        case .meal: return "fork.knife"
        case .insulin: return "syringe.fill"
        case .exercise: return "figure.run"
        }
    }

    var markerColor: Color {
        switch self {
        case .meal: return AmberTheme.amber
        case .insulin: return AmberTheme.amberLight
        case .exercise: return AmberTheme.cgaCyan
        }
    }

    /// Stack-order priority used when consolidating cross-type icons.
    /// Lower priority renders higher (top of stack).
    var stackPriority: Int {
        switch self {
        case .insulin: return 0
        case .meal: return 1
        case .exercise: return 2
        }
    }
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/Content/MarkerEntry.swift DOSBTSTests/MarkerEntryTests.swift
git commit -m "feat: MarkerEntry sum type with type-aware icon/colour dispatch"
```

---

### Task 7: EntryGroup with chronological grouping

**Files:**
- Create: `Library/Content/EntryGroup.swift`
- Create: `DOSBTSTests/EntryGroupTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// DOSBTSTests/EntryGroupTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("EntryGroup")
struct EntryGroupTests {
    @Test("group's anchor timestamp is the earliest entry")
    func anchorIsEarliest() {
        let t0 = Date(timeIntervalSince1970: 1_777_000_000)
        let m = MealEntry(timestamp: t0.addingTimeInterval(120), mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        let i = InsulinDelivery(starts: t0, ends: t0, units: 1, type: .mealBolus)
        let group = EntryGroup(entries: [.meal(m), .insulin(i)])
        #expect(group.anchorTimestamp == t0)
    }

    @Test("rows are returned chronologically")
    func chronologicalRows() {
        let t0 = Date(timeIntervalSince1970: 1_777_000_000)
        let i = InsulinDelivery(starts: t0, ends: t0, units: 1, type: .mealBolus)
        let m = MealEntry(timestamp: t0.addingTimeInterval(120), mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        let group = EntryGroup(entries: [.meal(m), .insulin(i)])
        let rows = group.chronologicalRows
        #expect(rows.first?.id == i.id)
        #expect(rows.last?.id == m.id)
    }

    @Test("groupAll consolidates entries within timegroup window")
    func groupingWindow() {
        let t0 = Date(timeIntervalSince1970: 1_777_000_000)
        let i = InsulinDelivery(starts: t0, ends: t0, units: 1, type: .mealBolus)
        let m = MealEntry(timestamp: t0.addingTimeInterval(60 * 12), mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        let groups = EntryGroup.groupAll(meals: [m], insulins: [i], exercises: [], windowMinutes: 15)
        #expect(groups.count == 1)
        #expect(groups[0].entries.count == 2)
    }

    @Test("entries 16+ minutes apart land in separate groups")
    func windowBoundary() {
        let t0 = Date(timeIntervalSince1970: 1_777_000_000)
        let i = InsulinDelivery(starts: t0, ends: t0, units: 1, type: .mealBolus)
        let m = MealEntry(timestamp: t0.addingTimeInterval(60 * 16), mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        let groups = EntryGroup.groupAll(meals: [m], insulins: [i], exercises: [], windowMinutes: 15)
        #expect(groups.count == 2)
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement `EntryGroup`**

```swift
// Library/Content/EntryGroup.swift
import Foundation

struct EntryGroup: Identifiable {
    let id = UUID()
    let entries: [MarkerEntry]

    var anchorTimestamp: Date {
        entries.map(\.timestamp).min() ?? Date()
    }

    var chronologicalRows: [MarkerEntry] {
        entries.sorted { $0.timestamp < $1.timestamp }
    }

    /// Groups entries whose timestamps fall within `windowMinutes` of each other.
    /// Used by `MarkerLaneView` to render consolidated cross-type clusters.
    static func groupAll(
        meals: [MealEntry],
        insulins: [InsulinDelivery],
        exercises: [ExerciseEntry],
        windowMinutes: Int = 15
    ) -> [EntryGroup] {
        let all: [MarkerEntry] =
            meals.map { .meal($0) } +
            insulins.map { .insulin($0) } +
            exercises.map { .exercise($0) }
        let sorted = all.sorted { $0.timestamp < $1.timestamp }

        let windowSeconds = TimeInterval(windowMinutes * 60)
        var groups: [[MarkerEntry]] = []
        for entry in sorted {
            if var last = groups.last,
               let lastTimestamp = last.first?.timestamp,
               entry.timestamp.timeIntervalSince(lastTimestamp) <= windowSeconds {
                last.append(entry)
                groups[groups.count - 1] = last
            } else {
                groups.append([entry])
            }
        }
        return groups.map { EntryGroup(entries: $0) }
    }
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/Content/EntryGroup.swift DOSBTSTests/EntryGroupTests.swift
git commit -m "feat: EntryGroup cross-type chronological grouping"
```

---

### Task 8: InsulinImpact view-layer model

**Files:**
- Create: `Library/Content/InsulinImpact.swift`
- Create: `DOSBTSTests/InsulinImpactTests.swift`

- [ ] **Step 1: Write failing tests for impact computation**

```swift
// DOSBTSTests/InsulinImpactTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("InsulinImpact")
struct InsulinImpactTests {
    @Test("delta is glucoseAtPeak minus glucoseAtDose, signed")
    func deltaSign() {
        let dose = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
        let impact = InsulinImpact.compute(
            for: dose,
            glucoseAtDose: 182,
            glucoseAtPeak: 114,
            peakOffsetMinutes: 72,
            iobAtDose: 1.8,
            confounders: []
        )
        #expect(impact.deltaMgDL == -68)
    }

    @Test("paired meal flag is true when entry group has a meal close to the dose")
    func pairedMealDetection() {
        let dose = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
        let meal = MealEntry(timestamp: dose.starts.addingTimeInterval(120), mealDescription: "x", carbsGrams: 45, analysisSessionId: nil)
        let isPaired = InsulinImpact.hasPairedMeal(for: dose, in: [.meal(meal), .insulin(dose)])
        #expect(isPaired == true)
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement `InsulinImpact`**

```swift
// Library/Content/InsulinImpact.swift
import Foundation

enum InsulinConfounder {
    case stackedBolus(units: Double)
    case exerciseInWindow
    case correctionForLow
}

struct InsulinImpact {
    let dose: InsulinDelivery
    let glucoseAtDose: Int?
    let glucoseAtPeak: Int?
    let peakOffsetMinutes: Int?
    let iobAtDose: Double?
    let confounders: [InsulinConfounder]

    var deltaMgDL: Int? {
        guard let g0 = glucoseAtDose, let g1 = glucoseAtPeak else { return nil }
        return g1 - g0
    }

    static func compute(
        for dose: InsulinDelivery,
        glucoseAtDose: Int?,
        glucoseAtPeak: Int?,
        peakOffsetMinutes: Int?,
        iobAtDose: Double?,
        confounders: [InsulinConfounder]
    ) -> InsulinImpact {
        InsulinImpact(
            dose: dose,
            glucoseAtDose: glucoseAtDose,
            glucoseAtPeak: glucoseAtPeak,
            peakOffsetMinutes: peakOffsetMinutes,
            iobAtDose: iobAtDose,
            confounders: confounders
        )
    }

    static func hasPairedMeal(for dose: InsulinDelivery, in groupEntries: [MarkerEntry]) -> Bool {
        groupEntries.contains { entry in
            if case .meal = entry { return true }
            return false
        }
    }
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add Library/Content/InsulinImpact.swift DOSBTSTests/InsulinImpactTests.swift
git commit -m "feat: InsulinImpact view-layer model"
```

---

## Phase 4 — Redux update actions

### Task 9: Add updateMealEntry / updateInsulinDelivery actions + reducer

**Files:**
- Modify: `Library/DirectAction.swift` (add two cases)
- Modify: `Library/DirectReducer.swift` (handle the two new cases)
- Modify: `DOSBTSTests/DirectReducerTests.swift` (cover the two cases)

- [ ] **Step 1: Write failing reducer test**

```swift
// DOSBTSTests/DirectReducerTests.swift (add to existing suite)
@Test("updateMealEntry replaces an existing entry by id")
func updateMealEntry() {
    var state = AppState(...)  // existing factory
    let original = MealEntry(timestamp: Date(), mealDescription: "Old", carbsGrams: 30, analysisSessionId: nil)
    state.mealEntryValues = [original]
    var updated = original
    updated.mealDescription = "New"
    updated.carbsGrams = 45
    DirectReducer.reducer(state: &state, action: .updateMealEntry(mealEntry: updated))
    #expect(state.mealEntryValues.count == 1)
    #expect(state.mealEntryValues.first?.mealDescription == "New")
    #expect(state.mealEntryValues.first?.carbsGrams == 45)
}

@Test("updateInsulinDelivery replaces an existing dose by id")
func updateInsulinDelivery() {
    var state = AppState(...)
    let original = InsulinDelivery(starts: Date(), ends: Date(), units: 4.5, type: .mealBolus)
    state.insulinDeliveryValues = [original]
    var updated = original
    updated.units = 5.0
    DirectReducer.reducer(state: &state, action: .updateInsulinDelivery(insulinDelivery: updated))
    #expect(state.insulinDeliveryValues.first?.units == 5.0)
}
```

- [ ] **Step 2: Run tests, expect FAIL** (action cases don't exist).

- [ ] **Step 3: Add the action cases**

```swift
// Library/DirectAction.swift — alphabetical position near other entry cases
case updateMealEntry(mealEntry: MealEntry)
case updateInsulinDelivery(insulinDelivery: InsulinDelivery)
```

- [ ] **Step 4: Add the reducer handlers**

```swift
// Library/DirectReducer.swift — inside the switch
case let .updateMealEntry(meal):
    if let idx = state.mealEntryValues.firstIndex(where: { $0.id == meal.id }) {
        state.mealEntryValues[idx] = meal
    }

case let .updateInsulinDelivery(insulin):
    if let idx = state.insulinDeliveryValues.firstIndex(where: { $0.id == insulin.id }) {
        state.insulinDeliveryValues[idx] = insulin
    }
```

- [ ] **Step 5: Run tests, expect PASS.**

- [ ] **Step 6: Commit**

```bash
git add Library/DirectAction.swift Library/DirectReducer.swift DOSBTSTests/DirectReducerTests.swift
git commit -m "feat: add update{Meal,Insulin} actions for upsert semantics"
```

---

### Task 10: Persist update actions in DataStore middleware

**Files:**
- Modify: `App/Modules/DataStore/MealEntryStore.swift` (add `.updateMealEntry` handler)
- Modify: `App/Modules/DataStore/InsulinDeliveryStore.swift` (add `.updateInsulinDelivery` handler)

- [ ] **Step 1: Add `.updateMealEntry` middleware case**

```swift
// MealEntryStore.swift — inside the switch in mealEntryStoreMiddleware
case .updateMealEntry(mealEntry: let mealEntry):
    DataStore.shared.updateMealEntry(mealEntry)
    return Just(.setMealEntryValues(mealEntryValues: DataStore.shared.fetchMealEntries()))
        .setFailureType(to: DirectError.self)
        .eraseToAnyPublisher()
```

Add `updateMealEntry(_:)` to `DataStore`:

```swift
// DataStore.swift (or MealEntryStore.swift extension)
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

- [ ] **Step 2: Add `.updateInsulinDelivery` middleware case (mirror)**

```swift
// InsulinDeliveryStore.swift
case .updateInsulinDelivery(insulinDelivery: let insulin):
    DataStore.shared.updateInsulinDelivery(insulin)
    return Just(.setInsulinDeliveryValues(insulinDeliveryValues: DataStore.shared.fetchInsulinDeliveries()))
        .setFailureType(to: DirectError.self)
        .eraseToAnyPublisher()
```

```swift
// DataStore.swift extension
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

- [ ] **Step 3: Build + run on simulator. Manually trigger an update via temporary debug button (or wait for combined modal). Verify persistence.**

- [ ] **Step 4: Commit**

```bash
git add App/Modules/DataStore/MealEntryStore.swift App/Modules/DataStore/InsulinDeliveryStore.swift App/Modules/DataStore/DataStore.swift
git commit -m "feat: persist updateMealEntry / updateInsulinDelivery via GRDB"
```

---

## Phase 5 — AddInsulinView rewrite (D4 standalone path)

### Task 11: Replace Picker + DatePicker with AmberChip + StepperField + QuickTimeChips

**Files:**
- Modify: `App/Views/AddViews/AddInsulinView.swift` (full rewrite)

- [ ] **Step 1: Replace the type picker, units field, and time picker**

Replace the existing `Picker("Type", selection: $insulinType)` and the units / time inputs with:

```swift
// AddInsulinView.swift — body
Form {
    Section("Type") {
        HStack(spacing: 4) {
            ForEach(InsulinType.allCases, id: \.self) { type in
                AmberChip(
                    label: type.shortLabel,
                    variant: .type,
                    tint: AmberTheme.amberLight,
                    isSelected: insulinType == type,
                    action: { insulinType = type }
                )
            }
        }
    }

    Section("Units") {
        StepperField(
            title: "Units",
            value: $units,
            step: 0.5,
            range: 0...50
        )
    }

    Section("Time") {
        QuickTimeChips(title: "Time", date: $starts)
    }

    if insulinType == .basal {
        Section("Ends") {
            DatePicker("Ends", selection: $ends, displayedComponents: [.date, .hourAndMinute])
        }
    }

    if insulinType == .correctionBolus, (currentIOB ?? 0) > 0.05 {
        Section { iobStackingWarning() }
    }

    Section {
        Button(action: save) {
            Text("Save").frame(maxWidth: .infinity)
        }
        .disabled((units ?? 0) <= 0)
    }

    if let editing = editingDelivery {
        Section {
            Button(role: .destructive, action: { confirmDelete = true }) {
                HStack {
                    Spacer()
                    Text("Delete").font(DOSTypography.body)
                    Spacer()
                }
            }
        }
    }
}
.confirmationDialog(
    "Delete this dose?",
    isPresented: $confirmDelete
) {
    Button("Delete", role: .destructive) {
        if let dose = editingDelivery {
            store.dispatch(.deleteInsulinDelivery(insulinDelivery: dose))
            dismiss()
        }
    }
}
```

Add `editingDelivery: InsulinDelivery?` parameter to `AddInsulinView` (optional, nil for new entries) and `@State private var confirmDelete = false`.

Add `InsulinType.shortLabel` computed property in `Library/Content/InsulinDelivery.swift`:

```swift
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

- [ ] **Step 2: Build app, expect success**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

- [ ] **Step 3: Run on simulator, tap sticky [INSULIN] button. Verify chip row, stepper, quick-time chips. Tap chips, see selection. Switch type to basal, see Ends picker reveal. Tap Save with units=0, see disabled.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/AddInsulinView.swift Library/Content/InsulinDelivery.swift
git commit -m "feat: AddInsulinView uses AmberChip + StepperField + QuickTimeChips"
```

---

## Phase 6 — MarkerLaneView (D1)

### Task 12: MarkerLaneView with cross-type cluster rendering

**Files:**
- Create: `App/Views/Overview/MarkerLaneView.swift`
- Create: `DOSBTSTests/MarkerLaneTests.swift`

- [ ] **Step 1: Write failing tests for hit testing**

```swift
// DOSBTSTests/MarkerLaneTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("MarkerLane hit testing")
struct MarkerLaneTests {
    @Test("tap on cluster centre returns the corresponding group")
    func tapResolvesToGroup() {
        let t = Date(timeIntervalSince1970: 1_777_000_000)
        let m = MealEntry(timestamp: t, mealDescription: "x", carbsGrams: 10, analysisSessionId: nil)
        let groups = [EntryGroup(entries: [.meal(m)])]
        let layout = MarkerLaneLayout(
            groups: groups,
            xCoordinate: { _ in 100 },
            laneWidth: 320
        )
        let hit = layout.groupAt(x: 100)
        #expect(hit?.id == groups[0].id)
    }

    @Test("tap with no group within 22pt returns nil")
    func tapMisses() {
        let layout = MarkerLaneLayout(groups: [], xCoordinate: { _ in 0 }, laneWidth: 320)
        #expect(layout.groupAt(x: 50) == nil)
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement `MarkerLaneView` + `MarkerLaneLayout`**

```swift
// App/Views/Overview/MarkerLaneView.swift
import SwiftUI

struct MarkerLaneLayout {
    let groups: [EntryGroup]
    let xCoordinate: (Date) -> CGFloat
    let laneWidth: CGFloat

    func groupAt(x: CGFloat) -> EntryGroup? {
        groups.min { lhs, rhs in
            abs(xCoordinate(lhs.anchorTimestamp) - x) < abs(xCoordinate(rhs.anchorTimestamp) - x)
        }.flatMap { closest in
            abs(xCoordinate(closest.anchorTimestamp) - x) <= 22 ? closest : nil
        }
    }
}

struct MarkerLaneView: View {
    let groups: [EntryGroup]
    let xCoordinate: (Date) -> CGFloat
    let onTap: (EntryGroup) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear
                ForEach(groups) { group in
                    let x = xCoordinate(group.anchorTimestamp)
                    clusterIcon(group)
                        .position(x: x, y: geo.size.height / 2)
                        .frame(width: 88, height: 48)
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(group) }
                        .accessibilityLabel(accessibilityLabel(for: group))
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private func clusterIcon(_ group: EntryGroup) -> some View {
        let sorted = group.entries.sorted { $0.stackPriority < $1.stackPriority }
        if sorted.count == 1, let entry = sorted.first {
            Image(systemName: entry.markerIcon)
                .font(.system(size: 22))
                .foregroundStyle(entry.markerColor)
        } else {
            ZStack {
                ForEach(Array(sorted.prefix(3).enumerated()), id: \.offset) { (idx, entry) in
                    Image(systemName: entry.markerIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(entry.markerColor)
                        .offset(y: CGFloat(idx) * -3)
                }
                if sorted.count > 1 {
                    Text("\(sorted.count)")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amber)
                        .padding(.horizontal, 3)
                        .background(Capsule().fill(.black))
                        .offset(x: 14, y: 10)
                }
            }
        }
    }

    private func accessibilityLabel(for group: EntryGroup) -> String {
        let labels = group.entries.map(label(for:)).joined(separator: ", ")
        return "Marker group \(group.entries.count) entries: \(labels)"
    }

    private func label(for entry: MarkerEntry) -> String {
        switch entry {
        case .meal(let m): return "meal \(Int(m.carbsGrams ?? 0)) grams"
        case .insulin(let i): return "insulin \(i.units, specifier: "%.1f") units"
        case .exercise(let e): return "exercise \(Int(e.durationMinutes)) minutes"
        }
    }
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add App/Views/Overview/MarkerLaneView.swift DOSBTSTests/MarkerLaneTests.swift
git commit -m "feat: MarkerLaneView with cross-type cluster rendering + hit testing"
```

---

## Phase 7 — EntryGroupListOverlay (D2)

### Task 13: Sub-line formatting helpers

**Files:**
- Create: `App/Views/Overview/EntryRowFormatter.swift`
- Create: `DOSBTSTests/EntryRowFormatterTests.swift`

- [ ] **Step 1: Write failing tests for sub-line text generation**

```swift
// DOSBTSTests/EntryRowFormatterTests.swift
import Testing
import Foundation
@testable import DOSBTSApp

@Suite("EntryRowFormatter")
struct EntryRowFormatterTests {
    @Test("meal sub-line includes count, time, delta when available")
    func mealSubline() {
        let t = ISO8601DateFormatter().date(from: "2026-04-25T14:32:00Z")!
        let m = MealEntry(timestamp: t, mealDescription: "x", carbsGrams: 45, analysisSessionId: nil)
        let line = EntryRowFormatter.subline(
            for: .meal(m),
            itemCount: 3,
            mealImpact: MealImpact(mealEntryId: m.id, baselineGlucose: 117, peakGlucose: 189, deltaMgDL: 72, timeToPeakMinutes: 105, isClean: true, timestamp: t),
            iob: nil,
            paired: false
        )
        #expect(line.contains("3 items"))
        #expect(line.contains("+72 mg/dL"))
    }

    @Test("meal sub-line shows computing… when no impact present")
    func mealNoImpact() {
        let t = Date()
        let m = MealEntry(timestamp: t, mealDescription: "x", carbsGrams: 45, analysisSessionId: nil)
        let line = EntryRowFormatter.subline(for: .meal(m), itemCount: 2, mealImpact: nil, iob: nil, paired: false)
        #expect(line.contains("computing"))
    }

    @Test("insulin sub-line shows minutes-before-meal when paired")
    func insulinPaired() {
        let t = Date()
        let i = InsulinDelivery(starts: t.addingTimeInterval(-180), ends: t.addingTimeInterval(-180), units: 4.5, type: .mealBolus)
        let line = EntryRowFormatter.subline(
            for: .insulin(i),
            itemCount: 0,
            mealImpact: nil,
            iob: 1.2,
            paired: true,
            mealStart: t
        )
        #expect(line.contains("3m before"))
        #expect(line.contains("IOB 1.2U"))
    }
}
```

- [ ] **Step 2: Run tests, expect FAIL.**

- [ ] **Step 3: Implement `EntryRowFormatter`**

```swift
// App/Views/Overview/EntryRowFormatter.swift
import Foundation

enum EntryRowFormatter {
    static func subline(
        for entry: MarkerEntry,
        itemCount: Int = 0,
        mealImpact: MealImpact? = nil,
        iob: Double? = nil,
        paired: Bool = false,
        mealStart: Date? = nil
    ) -> String {
        let time = timeFormatter.string(from: entry.timestamp)
        switch entry {
        case .meal:
            let parts = ["\(itemCount) items", time]
            if let impact = mealImpact {
                let sign = impact.deltaMgDL >= 0 ? "+" : ""
                return parts.joined(separator: " · ") + " · \(sign)\(impact.deltaMgDL) mg/dL"
            }
            return parts.joined(separator: " · ") + " · computing…"
        case .insulin(let dose):
            var parts = [time]
            if paired, let mealStart {
                let minutesBefore = Int(mealStart.timeIntervalSince(dose.starts) / 60)
                if minutesBefore > 0 { parts.append("\(minutesBefore)m before") }
            }
            if let iob, iob > 0.05 {
                parts.append(String(format: "IOB %.1fU", iob))
            }
            return parts.joined(separator: " · ")
        case .exercise(let ex):
            return [time, "\(Int(ex.durationMinutes))m", ex.workoutType ?? "exercise"].joined(separator: " · ")
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
```

- [ ] **Step 4: Run tests, expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add App/Views/Overview/EntryRowFormatter.swift DOSBTSTests/EntryRowFormatterTests.swift
git commit -m "feat: EntryRowFormatter sub-line text generation"
```

---

### Task 14: EntryGroupListOverlay sheet view

**Files:**
- Create: `App/Views/Overview/EntryGroupListOverlay.swift`

- [ ] **Step 1: Implement the read-overlay sheet**

```swift
// App/Views/Overview/EntryGroupListOverlay.swift
import SwiftUI

struct EntryGroupListOverlay: View {
    let group: EntryGroup
    let mealImpacts: [UUID: MealImpact]
    let iobAtTime: (Date) -> Double?
    var onEdit: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AmberTheme.amberDark)
            ForEach(Array(group.chronologicalRows.enumerated()), id: \.element.id) { idx, entry in
                row(for: entry)
                if idx < group.chronologicalRows.count - 1 {
                    Divider().background(AmberTheme.amberDark.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Text("OK")
                    .font(DOSTypography.button)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 2).fill(AmberTheme.amber))
            }
            .padding(DOSSpacing.md)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
        return f.string(from: group.anchorTimestamp)
    }

    private func row(for entry: MarkerEntry) -> some View {
        HStack(alignment: .top) {
            Image(systemName: entry.markerIcon)
                .foregroundStyle(entry.markerColor)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText(for: entry))
                    .font(DOSTypography.body)
                    .foregroundStyle(AmberTheme.amber)
                Text(EntryRowFormatter.subline(
                    for: entry,
                    itemCount: itemCount(for: entry),
                    mealImpact: mealImpact(for: entry),
                    iob: iobAt(entry: entry),
                    paired: hasPairedMeal(for: entry),
                    mealStart: pairedMealStart(for: entry)
                ))
                .font(DOSTypography.caption)
                .foregroundStyle(AmberTheme.amberDark)
            }
            Spacer()
            Text(valueText(for: entry))
                .font(DOSTypography.body)
                .foregroundStyle(entry.markerColor)
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func primaryText(for entry: MarkerEntry) -> String {
        switch entry {
        case .meal(let m): return m.mealDescription ?? "Meal"
        case .insulin(let i): return i.type.shortLabel.localizedCapitalized + " bolus"
        case .exercise(let e): return e.workoutType ?? "Exercise"
        }
    }

    private func valueText(for entry: MarkerEntry) -> String {
        switch entry {
        case .meal(let m): return "\(Int(m.carbsGrams ?? 0))g"
        case .insulin(let i): return String(format: "%.1fU", i.units)
        case .exercise(let e): return "\(Int(e.durationMinutes))m"
        }
    }

    private func itemCount(for entry: MarkerEntry) -> Int {
        if case .meal = entry { return 1 }  // single meal entry; multi-item count comes from the staging plate JSON, not exposed here
        return 0
    }

    private func mealImpact(for entry: MarkerEntry) -> MealImpact? {
        guard case let .meal(m) = entry else { return nil }
        return mealImpacts[m.id]
    }

    private func iobAt(entry: MarkerEntry) -> Double? {
        guard case .insulin = entry else { return nil }
        return iobAtTime(entry.timestamp)
    }

    private func hasPairedMeal(for entry: MarkerEntry) -> Bool {
        guard case .insulin = entry else { return false }
        return group.entries.contains { if case .meal = $0 { return true } else { return false } }
    }

    private func pairedMealStart(for entry: MarkerEntry) -> Date? {
        guard case .insulin = entry else { return nil }
        return group.entries.compactMap { if case let .meal(m) = $0 { return m.timestamp } else { return nil } }.first
    }
}
```

- [ ] **Step 2: Build app, expect success.**

- [ ] **Step 3: Manually verify (after Task 17 wires it into ChartView): tap a meal-only marker → 1-row overlay with delta. Tap a cross-type group → 2 rows in chronological order with subllines.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/Overview/EntryGroupListOverlay.swift
git commit -m "feat: EntryGroupListOverlay Libre-style read surface"
```

---

## Phase 8 — CombinedEntryEditView (D3)

### Task 15: Combined modal scaffolding (sections + Cancel/Save)

**Files:**
- Create: `App/Views/AddViews/CombinedEntryEditView.swift`

- [ ] **Step 1: Implement the modal shell with section headers and FOOD/INSULIN/TIME blocks**

```swift
// App/Views/AddViews/CombinedEntryEditView.swift
import SwiftUI

struct CombinedEntryEditView: View {
    @EnvironmentObject var store: DirectStore
    @Environment(\.dismiss) private var dismiss

    let originalGroup: EntryGroup

    // Editable copies
    @State private var meal: MealEntry?
    @State private var insulin: InsulinDelivery?
    @State private var stagedItems: [EditableFoodItem] = []
    @State private var description: String = ""
    @State private var time: Date = Date()
    @State private var insulinType: InsulinType = .mealBolus
    @State private var units: Double? = nil
    @State private var expandedItemID: UUID? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                foodSection
                Divider().background(AmberTheme.amberDark.opacity(0.5))
                insulinSection
                Divider().background(AmberTheme.amberDark.opacity(0.5))
                timeSection
                Spacer(minLength: 0)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isDirty)
                }
            }
        }
        .onAppear { hydrateFromGroup() }
    }

    private var navTitle: String {
        if meal != nil && insulin != nil { return "Meal + Insulin" }
        if meal != nil { return "Meal" }
        if insulin != nil { return "Insulin" }
        return "Edit"
    }

    // hydrate, isDirty, save, sections... (see Task 16)
}
```

- [ ] **Step 2: Add `hydrateFromGroup`**

```swift
private func hydrateFromGroup() {
    for entry in originalGroup.entries {
        switch entry {
        case .meal(let m):
            meal = m
            description = m.mealDescription ?? ""
            time = m.timestamp
            // stagedItems hydration: future enhancement reads the analysis session items;
            // v1 represents the meal as a single editable summary item if no analysis data is available
            stagedItems = [EditableFoodItem(name: m.mealDescription ?? "Meal", carbsG: m.carbsGrams ?? 0, currentAmountG: nil, baseServingG: nil, carbsPerG: nil)]
        case .insulin(let i):
            insulin = i
            insulinType = i.type
            units = i.units
        case .exercise:
            break  // exercise isn't editable through this surface
        }
    }
}

private var isDirty: Bool {
    guard let meal else {
        return insulin != nil  // insulin-only edits
    }
    let descChanged = (meal.mealDescription ?? "") != description
    let timeChanged = abs(meal.timestamp.timeIntervalSince(time)) > 1
    let carbsChanged = (meal.carbsGrams ?? 0) != stagedItems.reduce(0) { $0 + $1.carbsG }
    let insulinChanged: Bool = {
        guard let insulin else { return false }
        return insulin.units != units || insulin.type != insulinType || abs(insulin.starts.timeIntervalSince(time)) > 1
    }()
    return descChanged || timeChanged || carbsChanged || insulinChanged
}
```

- [ ] **Step 3: Build app, expect success.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/CombinedEntryEditView.swift
git commit -m "feat: CombinedEntryEditView scaffolding (Cancel/Save + section shell)"
```

---

### Task 16: Combined modal sections + accordion + save dispatch

**Files:**
- Modify: `App/Views/AddViews/CombinedEntryEditView.swift`

- [ ] **Step 1: Implement the three section bodies**

```swift
// CombinedEntryEditView.swift — add to body

@ViewBuilder
private var foodSection: some View {
    if meal != nil || stagedItems.isEmpty == false {
        VStack(alignment: .leading, spacing: DOSSpacing.sm) {
            HStack {
                Image(systemName: "fork.knife").foregroundStyle(AmberTheme.amber)
                Text("FOOD").font(DOSTypography.caption).foregroundStyle(AmberTheme.amber)
                Spacer()
                Text("\(stagedItems.count) items · \(Int(stagedItems.reduce(0) { $0 + $1.carbsG }))g")
                    .font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
            }
            TextField("Description", text: $description)
                .font(DOSTypography.body)
                .padding(.horizontal, DOSSpacing.sm).padding(.vertical, 4)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(AmberTheme.amberDark, lineWidth: 1))
            ForEach($stagedItems.prefix(5)) { $item in
                StagingPlateRowView(
                    item: $item,
                    onBarcodeRescan: { _ in },  // disabled in combined modal v1
                    isExpanded: expandedItemID == item.id,
                    onToggleExpand: {
                        expandedItemID = (expandedItemID == item.id) ? nil : item.id
                    }
                )
                .padding(.vertical, 2)
            }
            if stagedItems.count > 5 {
                ScrollView { ForEach($stagedItems.dropFirst(5)) { $item in /* same row */ } }
                    .frame(maxHeight: 120)
            }
            Button(action: addEmptyItem) {
                Label("Add item", systemImage: "plus")
                    .font(DOSTypography.caption)
                    .foregroundStyle(AmberTheme.amber)
            }
        }
        .padding(DOSSpacing.md)
    } else {
        Button(action: addEmptyItem) {
            Label("Add meal", systemImage: "plus")
                .foregroundStyle(AmberTheme.amber)
        }
        .padding(DOSSpacing.md)
    }
}

@ViewBuilder
private var insulinSection: some View {
    if insulin != nil || units != nil {
        VStack(alignment: .leading, spacing: DOSSpacing.sm) {
            HStack {
                Image(systemName: "syringe.fill").foregroundStyle(AmberTheme.amberLight)
                Text("INSULIN").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberLight)
                Spacer()
                if let u = units {
                    Text("\(insulinType.shortLabel.lowercased()) · \(u, specifier: "%.1f")U")
                        .font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                }
            }
            HStack(spacing: 4) {
                ForEach(InsulinType.allCases, id: \.self) { t in
                    AmberChip(label: t.shortLabel, variant: .type, tint: AmberTheme.amberLight, isSelected: t == insulinType, action: { insulinType = t })
                }
            }
            StepperField(title: "Units", value: $units, step: 0.5, range: 0...50)
        }
        .padding(DOSSpacing.md)
    } else {
        Button(action: { units = 1.0; insulinType = .mealBolus }) {
            Label("Add insulin", systemImage: "plus").foregroundStyle(AmberTheme.amberLight)
        }
        .padding(DOSSpacing.md)
    }
}

private var timeSection: some View {
    HStack {
        Image(systemName: "clock").foregroundStyle(AmberTheme.amber)
        Text("TIME (shared)").font(DOSTypography.caption).foregroundStyle(AmberTheme.amber)
        Spacer()
        DatePicker("", selection: $time, displayedComponents: [.date, .hourAndMinute])
            .labelsHidden()
    }
    .padding(DOSSpacing.md)
}

private func addEmptyItem() {
    stagedItems.append(EditableFoodItem(name: "", carbsG: 0, currentAmountG: nil, baseServingG: nil, carbsPerG: nil))
    expandedItemID = stagedItems.last?.id
}
```

- [ ] **Step 2: Implement `save()`**

```swift
private func save() {
    if var m = meal {
        m.mealDescription = description.isEmpty ? nil : description
        m.timestamp = time
        m.carbsGrams = stagedItems.reduce(0) { $0 + $1.carbsG }
        store.dispatch(.updateMealEntry(mealEntry: m))
    }
    if var i = insulin, let u = units, u > 0 {
        i.units = u
        i.type = insulinType
        i.starts = time
        if i.type != .basal { i.ends = time }
        store.dispatch(.updateInsulinDelivery(insulinDelivery: i))
    } else if insulin == nil, let u = units, u > 0 {
        let new = InsulinDelivery(starts: time, ends: time, units: u, type: insulinType)
        store.dispatch(.addInsulinDelivery(insulinDeliveryValues: [new]))
    }
    if meal == nil, stagedItems.contains(where: { $0.carbsG > 0 }) {
        let new = MealEntry(
            timestamp: time,
            mealDescription: description.isEmpty ? nil : description,
            carbsGrams: stagedItems.reduce(0) { $0 + $1.carbsG },
            analysisSessionId: nil
        )
        store.dispatch(.addMealEntry(mealEntryValues: [new]))
    }
    dismiss()
}
```

- [ ] **Step 3: Build, expect success.**

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/CombinedEntryEditView.swift
git commit -m "feat: CombinedEntryEditView sections + accordion + save dispatch"
```

---

## Phase 9 — ChartView integration

### Task 17: Replace in-chart marker handling with MarkerLaneView + sheet plumbing

**Files:**
- Modify: `App/Views/Overview/ChartView.swift` (drop `tappedInsulinEntry` confirmDialog, drop `activeMealOverlay` inline card, mount `MarkerLaneView`)
- Modify: `App/Views/OverviewView.swift` (add `entryGroupReadOverlay` and `combinedEntryEdit` cases to `ActiveSheet`)

- [ ] **Step 1: Add the two new ActiveSheet cases**

```swift
// OverviewView.swift — extend the enum
private enum ActiveSheet: Identifiable {
    case insulin
    case meal
    case bloodGlucose
    case treatmentModal(alarmFiredAt: Date)
    case filteredFoodEntry
    case treatmentRecheck(glucoseValue: Int)
    case entryGroupReadOverlay(EntryGroup)        // ← new
    case combinedEntryEdit(EntryGroup)            // ← new

    var id: String {
        switch self {
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

- [ ] **Step 2: Add the sheet bodies for the two new cases**

```swift
// OverviewView.swift — inside the .sheet(item:) ViewBuilder
case .entryGroupReadOverlay(let group):
    EntryGroupListOverlay(
        group: group,
        mealImpacts: Dictionary(uniqueKeysWithValues: store.state.mealImpactValues.map { ($0.mealEntryId, $0) }),
        iobAtTime: { _ in store.state.activeIOB },
        onEdit: {
            pendingSheet = .combinedEntryEdit(group)
            activeSheet = nil  // dismiss → onDismiss presents pendingSheet
        },
        onDismiss: { activeSheet = nil }
    )
case .combinedEntryEdit(let group):
    CombinedEntryEditView(originalGroup: group)
        .environmentObject(store)
```

- [ ] **Step 3: In `ChartView`, drop the existing `tappedInsulinEntry` confirmationDialog, drop the `activeMealOverlay` inline card. Add `MarkerLaneView` below the chart**

In `ChartView.swift`:
1. Delete lines around 215 (`.confirmationDialog` for tappedInsulinEntry) and 575–680 (the `if let overlayMeal = activeMealOverlay` block).
2. Delete `@State private var tappedInsulinEntry` (line 999) and `@State private var activeMealOverlay` (line 1003).
3. Delete `computeMealOverlayDelta(meal:isInProgress:)` and `detectMealConfounders(meal:)` (lines 1415–end, keep them — they're still used by the impact card data, but we now wire them through `EntryGroupListOverlay` via `mealImpactValues` state instead. Verify no caller breaks.)
4. Below the chart, add:

```swift
// ChartView.swift — inside the main body, after the chart
MarkerLaneView(
    groups: EntryGroup.groupAll(
        meals: visibleMeals,
        insulins: visibleInsulins,
        exercises: visibleExercises,
        windowMinutes: 15
    ),
    xCoordinate: { ts in self.xCoordinate(for: ts) },  // existing chart coordinate helper
    onTap: { group in
        store.dispatch(.setSelectedEntryGroup(entryGroup: group))
    }
)
.frame(height: 32)
```

Wire the dispatch via a new ephemeral action `setSelectedEntryGroup(entryGroup: EntryGroup?)`:
- Add to `DirectAction.swift`: `case setSelectedEntryGroup(entryGroup: EntryGroup?)`.
- Add to `DirectState.swift` + `AppState.swift`: `var selectedEntryGroup: EntryGroup?` (no UserDefaults persistence — ephemeral).
- Add reducer case.
- In OverviewView, observe state changes:

```swift
.onChange(of: store.state.selectedEntryGroup) { _, group in
    if let group {
        activeSheet = .entryGroupReadOverlay(group)
        store.dispatch(.setSelectedEntryGroup(entryGroup: nil))
    }
}
```

- [ ] **Step 4: Build app**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -sdk iphonesimulator -configuration Debug build
```

Expected: success.

- [ ] **Step 5: Run on simulator. Tap a meal marker, confirm list overlay opens. Tap a cross-type cluster, confirm both rows show. Tap Edit, confirm combined modal opens (sheet swap). Edit description, tap Save, confirm chart re-renders with the new entry data.**

- [ ] **Step 6: Commit**

```bash
git add Library/DirectAction.swift Library/DirectState.swift Library/DirectReducer.swift App/AppState.swift App/Views/OverviewView.swift App/Views/Overview/ChartView.swift
git commit -m "feat: ChartView routes marker taps to EntryGroupListOverlay + CombinedEntryEditView"
```

---

## Phase 10 — D8 delete affordance moves

### Task 18: Verify D8 delete behaviour and remove dead code

**Files:**
- Modify: `App/Views/Overview/ChartView.swift` (verify confirmDialog was deleted; remove any stale state)

- [ ] **Step 1: Search for any remaining `tappedInsulinEntry` references**

```bash
grep -nE 'tappedInsulinEntry|deleteInsulinDeliveryConfirm' App/Views/Overview/ChartView.swift
```

Expected: no matches.

- [ ] **Step 2: Verify `AddInsulinView` Delete button (added in Task 11) wraps in a `confirmationDialog` and dispatches `.deleteInsulinDelivery`. Run app, tap a logged insulin marker → list overlay → Edit → Combined modal. Swipe-to-delete inside the modal (added in Task 16's stagedItems / insulin section): swipe wipes the section.**

The combined modal's swipe-to-delete is implicit through removing items from `stagedItems` (the empty section then shows the `+ add ...` placeholder). Verify by:

- Open a combined modal with both meal + insulin
- Swipe the insulin row left → row removed → section shows `+ add insulin`
- Tap Save → `deleteInsulinDelivery` dispatched, no Update for insulin

Update `save()` in `CombinedEntryEditView` to handle this:

```swift
// CombinedEntryEditView.swift — extend save()
if let originalInsulin = originalGroup.entries.compactMap({ if case let .insulin(i) = $0 { return i } else { return nil } }).first,
   insulin == nil && units == nil {
    store.dispatch(.deleteInsulinDelivery(insulinDelivery: originalInsulin))
}
if let originalMeal = originalGroup.entries.compactMap({ if case let .meal(m) = $0 { return m } else { return nil } }).first,
   meal == nil && stagedItems.allSatisfy({ $0.carbsG == 0 }) {
    store.dispatch(.deleteMealEntry(mealEntry: originalMeal))
}
```

- [ ] **Step 3: Manually verify both delete paths work end-to-end:**
  - Standalone `AddInsulinView` (sticky button → existing dose edit) → Delete button → confirm → entry removed
  - Combined modal → swipe-to-delete one section → Save → only that section's entry removed

- [ ] **Step 4: Commit**

```bash
git add App/Views/AddViews/CombinedEntryEditView.swift
git commit -m "feat: D8 delete affordances live only in Edit surfaces"
```

---

## Final verification + smoke tests

### Task 19: Full-build verification + manual smoke

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild -project DOSBTS.xcodeproj -scheme DOSBTSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected: all tests pass (existing 138+ plus new ones added in this plan).

- [ ] **Step 2: Manual smoke checklist on simulator**

For each, run app on iPhone 17 Pro simulator:

1. Tap a single meal marker → list overlay shows 1 row + sub-line with delta + OK
2. Tap a single insulin marker → list overlay shows 1 row + sub-line with IOB + OK (no Delete dialog)
3. Tap a cross-type cluster (meal+bolus within 15 min) → list overlay shows 2 rows in chronological order
4. Tap Edit on a meal-only group → combined modal with FOOD section, INSULIN section showing `+ add insulin`, TIME shared
5. Tap Edit on cross-type → both sections populated
6. In combined modal, expand one plate row, change Amount → Carbs auto-scale
7. Type a manual carb value → `manual` indicator
8. Expand a second row → first row auto-collapses (accordion)
9. Tap Save → chart re-renders with updated values, sheet dismisses
10. Open standalone AddInsulinView (sticky [INSULIN] button) → chips, stepper, quick-time chips, Delete button visible only when editing
11. Open `FoodPhotoAnalysisView` (sticky [MEAL] → photo) → staging plate uses `StagingPlateRowView`, all today's affordances intact (Clarify, Confidence, disclaimer still present)

- [ ] **Step 3: Commit summary entry to CHANGELOG**

```bash
# Append under [Unreleased] in CHANGELOG.md:
#   ### Added
#   - Unified marker → read overlay → edit flow (DMNC-848). Tapping any chart marker opens a Libre-style list overlay; Edit opens a single combined modal.
#   - AmberChip, StepperField, QuickTimeChips design-system primitives.
#   - StagingPlateRowView extraction (shared between FoodPhotoAnalysisView and CombinedEntryEditView).
#   ### Changed
#   - AddInsulinView replaces Picker with chip row + stepper + quick-time chips.
#   - Insulin-marker tap no longer shows a bare Delete dialog; delete now requires entering Edit.

git add CHANGELOG.md
git commit -m "docs: changelog — DMNC-848 unified marker + entry experience"
```

---

## Self-review

- [ ] **Spec coverage check:**
  - D1 (markers): Tasks 6, 7, 12 ✓
  - D2 (list overlay): Tasks 13, 14, 17 ✓
  - D3 (combined modal): Tasks 9, 10, 15, 16 ✓
  - D4 (primitives): Tasks 1, 2, 3, 11 ✓
  - D5 (StagingPlateRowView): Tasks 4, 5 ✓
  - D8 (delete moves): Tasks 11, 18 ✓
  - Migration (no GRDB changes): ✓ (Task 9, 10 are upserts)
  - Sheet plumbing (no nested): Task 17 ✓

- [ ] **Type consistency check:** `EditableFoodItem` is referenced from existing code (`FoodPhotoAnalysisView`); confirmed it has the fields used (`name`, `carbsG`, `currentAmountG`, `baseServingG`, `carbsPerG`, `isExpanded`).
