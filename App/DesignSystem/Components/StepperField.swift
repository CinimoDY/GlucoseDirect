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
