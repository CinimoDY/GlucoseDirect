//
//  StepperField.swift
//  DOSBTS
//

import SwiftUI

struct StepperField: View {
    let title: String
    @Binding var value: Double?
    let step: Double
    let range: ClosedRange<Double>
    var unit: String = ""
    var helpText: String? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Button {
                    Self.decrement(&value, step: step, range: range)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AmberTheme.amber)
                        .frame(width: 60, height: 56)
                        .background(AmberTheme.amber.opacity(0.08))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ZStack {
                    if isFocused || value == nil {
                        TextField("", value: $value, format: .number.precision(.fractionLength(1)))
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .foregroundStyle(AmberTheme.amber)
                    } else if let v = value {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", v))
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AmberTheme.amber)
                            if !unit.isEmpty {
                                Text(unit)
                                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                                    .foregroundStyle(AmberTheme.amberDark)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }

                Button {
                    Self.increment(&value, step: step, range: range)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AmberTheme.amber)
                        .frame(width: 60, height: 56)
                        .background(AmberTheme.amber.opacity(0.08))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(AmberTheme.amberDark, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))

            if let helpText {
                Text(helpText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AmberTheme.amberDark.opacity(0.7))
            }
        }
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
