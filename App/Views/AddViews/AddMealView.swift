//
//  AddMealView.swift
//  DOSBTSApp
//

import SwiftUI

struct AddMealView: View {
    @Environment(\.dismiss) var dismiss

    @FocusState private var descriptionFocus: Bool

    @State var timestamp: Date = .init()
    @State var mealDescription: String = ""
    @State var carbsGrams: Double?

    var addCallback: (_ timestamp: Date, _ mealDescription: String, _ carbsGrams: Double?) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                        HStack {
                            Text("Description")

                            TextField("", text: $mealDescription)
                                .textFieldStyle(.automatic)
                                .focused($descriptionFocus)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("Carbs (g)")

                            TextField("", value: $carbsGrams, format: .number)
                                .textFieldStyle(.automatic)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            DatePicker(
                                "Time",
                                selection: $timestamp,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                }, footer: {
                    Text("Log meals to see them as markers on your glucose chart.")
                })
            }
            .navigationTitle("Meal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let clampedDescription = String(trimmed.prefix(200))
                        let clampedCarbs = carbsGrams.flatMap { $0 >= 0 && $0 <= 1000 ? $0 : nil }
                        addCallback(timestamp, clampedDescription, clampedCarbs)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }.onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    self.descriptionFocus = true
                }
            }
        }
    }
}

struct AddMealView_Previews: PreviewProvider {
    static var previews: some View {
        Button("Modal always shown") {}
            .sheet(isPresented: .constant(true)) {
                AddMealView { _, _, _ in
                }
            }
    }
}
