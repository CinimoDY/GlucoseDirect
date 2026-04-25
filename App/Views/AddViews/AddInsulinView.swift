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
        VStack(spacing: 0) {
            navBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    typeRow
                    unitsRow
                    timeRow

                    if insulinType == .basal {
                        endsRow
                    }

                    if insulinType == .correctionBolus, (currentIOB ?? 0) > 0.05 {
                        iobWarning
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(AmberTheme.amberDark)

            Spacer()

            Text("ADD INSULIN")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AmberTheme.amberLight)

            Spacer()

            Button("Add") { save() }
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle((units ?? 0) > 0 ? AmberTheme.amber : AmberTheme.amberDark.opacity(0.4))
                .disabled((units ?? 0) <= 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AmberTheme.amberDark.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Form rows

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(AmberTheme.amberDark)
    }

    private var typeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("TYPE")
            HStack(spacing: 6) {
                ForEach(InsulinType.allCases, id: \.self) { type in
                    AmberChip(
                        label: type.shortLabel,
                        variant: .type,
                        tint: AmberTheme.amber,
                        isSelected: insulinType == type,
                        action: { insulinType = type }
                    )
                }
            }
        }
    }

    private var unitsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("UNITS")
            StepperField(
                title: "Units",
                value: $units,
                step: 0.5,
                range: 0...50,
                unit: "U",
                helpText: "tap value to type · ±0.5U steps"
            )
        }
    }

    private var timeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel(insulinType == .basal ? "STARTS" : "TIME")
            QuickTimeChips(title: "Time", date: $starts)
        }
    }

    private var endsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            formLabel("ENDS")
            DatePicker("", selection: $ends, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AmberTheme.amber)
        }
    }

    private var iobWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AmberTheme.amber)
            Text("ACTIVE IOB: \(String(format: "%.1f", currentIOB ?? 0))U")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AmberTheme.amber)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AmberTheme.amber.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(AmberTheme.amber.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Save

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
