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
            HStack {
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
            }
            .navigationTitle("Meal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !mealDescription.isEmpty {
                            addCallback(timestamp, mealDescription, carbsGrams)
                            dismiss()
                        }
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
