//
//  AddInsulinView.swift
//  DOSBTSApp
//

import SwiftUI

struct AddInsulinView: View {
    @Environment(\.dismiss) var dismiss

    @State var starts: Date = .init()
    @State var ends: Date = .init()
    @State var units: Double?
    @State var insulinType: InsulinType = .snackBolus

    var addCallback: (_ starts: Date, _ ends: Date, _ units: Double, _ insulinType: InsulinType) -> Void
    var currentIOB: Double? = nil

    var body: some View {
        NavigationStack {
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
                        Text("Add").frame(maxWidth: .infinity)
                    }
                    .disabled((units ?? 0) <= 0)
                }
            }
            .navigationTitle("Insulin")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        guard let u = units, u > 0 else { return }
        let endsTime = insulinType == .basal ? ends : starts
        addCallback(starts, endsTime, u, insulinType)
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
