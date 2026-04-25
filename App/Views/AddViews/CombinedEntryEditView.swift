//
//  CombinedEntryEditView.swift
//  DOSBTS
//

import SwiftUI

struct CombinedEntryEditView: View {
    @EnvironmentObject var store: DirectStore
    @Environment(\.dismiss) private var dismiss

    let originalGroup: ConsolidatedMarkerGroup

    // Hydrated originals (id-preserved on save)
    @State private var originalMealEntry: MealEntry?
    @State private var originalInsulinDelivery: InsulinDelivery?

    // Editable shadow state
    @State private var stagedItems: [EditableFoodItem] = []
    @State private var description: String = ""
    @State private var time: Date = Date()
    @State private var endsTime: Date = Date()
    @State private var insulinType: InsulinType = .mealBolus
    @State private var units: Double? = nil
    @State private var expandedItemID: UUID? = nil
    @State private var showDiscardConfirm: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    foodSection
                    Divider().background(AmberTheme.amberDark.opacity(0.5))
                    insulinSection
                    Divider().background(AmberTheme.amberDark.opacity(0.5))
                    timeSection
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isDirty)
                }
            }
        }
        .onAppear { hydrateFromGroup() }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) { }
        }
    }

    private var navTitle: String {
        if originalMealEntry != nil && originalInsulinDelivery != nil { return "Meal + Insulin" }
        if originalMealEntry != nil { return "Meal" }
        if originalInsulinDelivery != nil { return "Insulin" }
        return "Edit"
    }

    // MARK: - Hydration

    private func hydrateFromGroup() {
        for marker in originalGroup.markers {
            switch marker.type {
            case .meal:
                if let m = store.state.mealEntryValues.first(where: { $0.id == marker.sourceID }) {
                    originalMealEntry = m
                    description = m.mealDescription
                    time = m.timestamp
                    // V1: single editable summary item. Multi-item hydration via analysisSessionId
                    // is a future enhancement (v2 plan flags this; banner shows count if >1 item).
                    stagedItems = [
                        EditableFoodItem(
                            id: UUID(),
                            name: m.mealDescription,
                            carbsG: m.carbsGrams ?? 0,
                            isExpanded: false,
                            baseServingG: nil,
                            currentAmountG: nil,
                            carbsPerG: nil
                        )
                    ]
                }
            case .bolus:
                if let i = store.state.insulinDeliveryValues.first(where: { $0.id == marker.sourceID }) {
                    originalInsulinDelivery = i
                    insulinType = i.type
                    units = i.units
                    if originalMealEntry == nil {
                        // No meal anchor: use insulin's start as the shared time
                        time = i.starts
                    }
                    endsTime = i.ends
                }
            case .exercise:
                break  // not editable here
            }
        }
    }

    // MARK: - isDirty

    private var isDirty: Bool {
        var dirty = false
        if let m = originalMealEntry {
            if m.mealDescription != description { dirty = true }
            if abs(m.timestamp.timeIntervalSince(time)) > 1 { dirty = true }
            if (m.carbsGrams ?? 0) != stagedItems.reduce(0, { $0 + $1.carbsG }) { dirty = true }
        }
        if let i = originalInsulinDelivery {
            if i.units != (units ?? 0) { dirty = true }
            if i.type != insulinType { dirty = true }
            if abs(i.starts.timeIntervalSince(time)) > 1 { dirty = true }
        }
        return dirty
    }

    // MARK: - Cancel/Save

    private func cancel() {
        if isDirty {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }

    private func save() {
        // MEAL update — id-preserving constructor (no `let` mutation)
        if let original = originalMealEntry {
            let totalCarbs = stagedItems.reduce(0.0, { $0 + $1.carbsG })
            // Delete-via-empty: cleared description AND all carbs zero/empty
            if description.isEmpty && totalCarbs == 0 {
                store.dispatch(.deleteMealEntry(mealEntry: original))
            } else {
                let updated = MealEntry(
                    id: original.id,
                    timestamp: time,
                    mealDescription: description.isEmpty ? original.mealDescription : description,
                    carbsGrams: totalCarbs,
                    proteinGrams: original.proteinGrams,
                    fatGrams: original.fatGrams,
                    calories: original.calories,
                    fiberGrams: original.fiberGrams,
                    analysisSessionId: original.analysisSessionId
                )
                store.dispatch(.updateMealEntry(mealEntry: updated))
            }
        }

        // INSULIN update — id-preserving constructor
        if let original = originalInsulinDelivery {
            // Delete-via-empty: nil or zero units
            if (units ?? 0) == 0 {
                store.dispatch(.deleteInsulinDelivery(insulinDelivery: original))
            } else if let u = units {
                let updated = InsulinDelivery(
                    id: original.id,
                    starts: time,
                    ends: insulinType == .basal ? endsTime : time,
                    units: u,
                    type: insulinType
                )
                store.dispatch(.updateInsulinDelivery(insulinDelivery: updated))
            }
        }

        // No auto-create (v2): empty companion section is a no-op for that section.
        dismiss()
    }

    // MARK: - Sections

    @ViewBuilder
    private var foodSection: some View {
        if originalMealEntry != nil {
            VStack(alignment: .leading, spacing: DOSSpacing.sm) {
                HStack {
                    Image(systemName: "fork.knife").foregroundStyle(AmberTheme.cgaGreen)
                    Text("FOOD").font(DOSTypography.caption).foregroundStyle(AmberTheme.cgaGreen)
                    Spacer()
                    Text("\(stagedItems.count) item\(stagedItems.count == 1 ? "" : "s") · \(Int(stagedItems.reduce(0, { $0 + $1.carbsG })))g")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
                TextField("Description", text: $description)
                    .font(DOSTypography.body)
                    .padding(.horizontal, DOSSpacing.sm)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(AmberTheme.amberDark, lineWidth: 1)
                    )
                ForEach($stagedItems) { $item in
                    StagingPlateRowView(
                        item: $item,
                        onBarcodeRescan: { _ in },  // disabled in combined modal v1
                        isExpanded: expandedItemID == item.id,
                        onToggleExpand: {
                            withAnimation(.linear(duration: 0.18)) {
                                expandedItemID = (expandedItemID == item.id) ? nil : item.id
                            }
                        }
                    )
                    .padding(.vertical, 2)
                }
                if originalMealEntry?.analysisSessionId != nil, stagedItems.count == 1 {
                    Text("This meal was analyzed with multiple items. Editing here updates the total only.")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
            }
            .padding(DOSSpacing.md)
        }
    }

    @ViewBuilder
    private var insulinSection: some View {
        if originalInsulinDelivery != nil {
            VStack(alignment: .leading, spacing: DOSSpacing.sm) {
                HStack {
                    Image(systemName: "syringe.fill").foregroundStyle(AmberTheme.amberLight)
                    Text("INSULIN").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberLight)
                    Spacer()
                    if let u = units {
                        Text("\(insulinType.shortLabel) · \(String(format: "%.1f", u))U")
                            .font(DOSTypography.caption)
                            .foregroundStyle(AmberTheme.amberDark)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(InsulinType.allCases, id: \.self) { t in
                        AmberChip(
                            label: t.shortLabel,
                            variant: .type,
                            tint: AmberTheme.amberLight,
                            isSelected: t == insulinType,
                            action: { insulinType = t }
                        )
                    }
                }
                StepperField(
                    title: "Units",
                    value: $units,
                    step: 0.5,
                    range: 0...50
                )
            }
            .padding(DOSSpacing.md)
        }
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: DOSSpacing.sm) {
            HStack {
                Image(systemName: "clock").foregroundStyle(AmberTheme.amber)
                Text("TIME (shared)")
                    .font(DOSTypography.caption)
                    .foregroundStyle(AmberTheme.amber)
                Spacer()
                DatePicker("", selection: $time, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            if originalInsulinDelivery != nil, insulinType == .basal {
                HStack {
                    Image(systemName: "clock.badge.checkmark").foregroundStyle(AmberTheme.amberDark)
                    Text("ENDS").font(DOSTypography.caption).foregroundStyle(AmberTheme.amberDark)
                    Spacer()
                    DatePicker("", selection: $endsTime, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
            }
        }
        .padding(DOSSpacing.md)
    }
}
