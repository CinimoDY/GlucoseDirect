//
//  AddInsulinView.swift
//  DOSBTSApp
//

import SwiftUI

struct AddInsulinView: View {
    @EnvironmentObject var store: DirectStore
    @Environment(\.dismiss) var dismiss

    @State var starts: Date = .init()
    @State var ends: Date = .init()
    @State var units: Double?
    @State var insulinType: InsulinType = .snackBolus
    @State private var confirmDelete = false

    var addCallback: (_ starts: Date, _ ends: Date, _ units: Double, _ insulinType: InsulinType) -> Void
    var currentIOB: Double? = nil
    var editingDelivery: InsulinDelivery? = nil

    init(
        addCallback: @escaping (Date, Date, Double, InsulinType) -> Void,
        currentIOB: Double? = nil,
        editingDelivery: InsulinDelivery? = nil
    ) {
        self.addCallback = addCallback
        self.currentIOB = currentIOB
        self.editingDelivery = editingDelivery
        if let editing = editingDelivery {
            _starts = State(initialValue: editing.starts)
            _ends = State(initialValue: editing.ends)
            _units = State(initialValue: editing.units)
            _insulinType = State(initialValue: editing.type)
        }
    }

    var body: some View {
        NavigationView {
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

                Section(insulinType == .basal ? "Starts" : "Time") {
                    QuickTimeChips(title: "Time", date: $starts)
                }

                if insulinType == .basal {
                    Section("Ends") {
                        DatePicker("Ends", selection: $ends, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                if insulinType == .correctionBolus, (currentIOB ?? 0) > 0.05 {
                    Section {
                        HStack(spacing: DOSSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("ACTIVE IOB: \(String(format: "%.1f", currentIOB ?? 0))U")
                        }
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amber)
                    }
                }

                Section {
                    Button(action: save) {
                        Text(editingDelivery == nil ? "Add" : "Save")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled((units ?? 0) <= 0)
                }

                if editingDelivery != nil {
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
            .navigationTitle("Insulin")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete this dose?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let dose = editingDelivery {
                        store.dispatch(.deleteInsulinDelivery(insulinDelivery: dose))
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func save() {
        guard let u = units, u > 0 else { return }
        let endsTime = insulinType == .basal ? ends : starts
        if let editing = editingDelivery {
            let updated = InsulinDelivery(
                id: editing.id,
                starts: starts,
                ends: endsTime,
                units: u,
                type: insulinType
            )
            store.dispatch(.updateInsulinDelivery(insulinDelivery: updated))
        } else {
            addCallback(starts, endsTime, u, insulinType)
        }
        dismiss()
    }
}

struct AddInsulinView_Previews: PreviewProvider {
    static var previews: some View {
        Button("Modal always shown") {}
            .sheet(isPresented: .constant(true)) {
                AddInsulinView(addCallback: { _, _, _, _ in })
            }
    }
}
