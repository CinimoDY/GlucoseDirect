//
//  FoodPhotoAnalysisView.swift
//  DOSBTS
//

import PhotosUI
import SwiftUI

// MARK: - EditableFoodItem

/// Staging plate item — editable copy of a NutritionItem
struct EditableFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var carbsG: Double
    var isExpanded: Bool = false
}

// MARK: - FoodPhotoAnalysisView

struct FoodPhotoAnalysisView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                if !store.state.aiConsentFoodPhoto {
                    consentSection
                } else if store.state.foodAnalysisLoading {
                    loadingSection
                } else if let result = store.state.foodAnalysisResult {
                    resultsSection(result)
                } else if let error = store.state.foodAnalysisError {
                    errorSection(error)
                } else {
                    photoPickerSection
                }
            }
            .navigationTitle("AI Meal Analysis")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.dispatch(.setFoodAnalysisResult(result: nil))
                        store.dispatch(.setFoodAnalysisLoading(isLoading: false))
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @State private var selectedItem: Any?
    @State private var showCamera = false
    @State private var showConsentSheet = false
    @State private var showImagePicker = false

    // Staging plate state
    @State private var stagedItems: [EditableFoodItem] = []
    @State private var editDescription = ""
    @State private var editTimestamp = Date()
    @State private var totalsOverridden = false
    @State private var overrideCarbs: Double?
    @State private var overrideProtein: Double?
    @State private var overrideFat: Double?
    @State private var overrideCalories: Double?
    @State private var overrideFiber: Double?
    @FocusState private var focusedItemID: UUID?

    // Progress animation
    @State private var analysisPhase = 0
    @State private var progressTimer: Timer?

    private let analysisPhases = [
        "Identifying foods...",
        "Estimating portions...",
        "Calculating nutrition...",
        "Finalizing results...",
    ]

    // Auto-computed totals from staged items
    private var computedCarbs: Double {
        stagedItems.reduce(0) { $0 + $1.carbsG }
    }

    private var consentSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(AmberTheme.amber)

                Text("AI-powered food analysis requires sending your photo and food preferences to Anthropic (Claude AI).")
                    .font(DOSTypography.body)
                    .multilineTextAlignment(.center)

                Button("Set Up AI Analysis") {
                    showConsentSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(AmberTheme.amber)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .sheet(isPresented: $showConsentSheet) {
            AIConsentView {
                store.dispatch(.setAIConsentFoodPhoto(enabled: true))
            }
        }
    }

    // MARK: - Loading with progress phases

    private var loadingSection: some View {
        Section {
            VStack(spacing: DOSSpacing.md) {
                ProgressView()
                    .tint(AmberTheme.amber)

                Text(analysisPhases[analysisPhase])
                    .font(DOSTypography.body)
                    .foregroundStyle(AmberTheme.amber)
                    .animation(.easeInOut(duration: 0.3), value: analysisPhase)

                dosProgressBar
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .onAppear { startProgressTimer() }
            .onDisappear { stopProgressTimer() }
        }
    }

    private var dosProgressBar: some View {
        let filled = analysisPhase + 1
        let total = analysisPhases.count
        let bar = String(repeating: "=", count: filled * 3) + String(repeating: " ", count: (total - filled) * 3)
        return Text("[\(bar)]")
            .font(DOSTypography.caption)
            .foregroundStyle(AmberTheme.amberDark)
    }

    private func startProgressTimer() {
        analysisPhase = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if analysisPhase < analysisPhases.count - 1 {
                analysisPhase += 1
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Photo picker

    private var photoPickerSection: some View {
        Section(
            content: {
                if #available(iOS 16.0, *) {
                    photosPickerButton
                } else {
                    Button(action: { showImagePicker = true }) {
                        Label("Choose from Library", systemImage: "photo")
                    }
                    .sheet(isPresented: $showImagePicker) {
                        CameraView(sourceType: .photoLibrary) { image in
                            analyzeImage(image)
                        }
                    }
                }

                Button(action: { showCamera = true }) {
                    Label("Take Photo", systemImage: "camera")
                }
                .sheet(isPresented: $showCamera) {
                    CameraView { image in
                        analyzeImage(image)
                    }
                }
            },
            header: {
                Label("Food photo", systemImage: "fork.knife")
            },
            footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Take a photo of your meal to estimate nutritional content using Claude AI.")
                    if store.state.thumbCalibrationMM != nil {
                        Text("Hold your thumb next to the food for better portion accuracy.")
                            .foregroundStyle(AmberTheme.cgaGreen)
                    }
                    if store.state.claudeAPIKeyValid {
                        Text("Estimated cost: typically less than $0.01 per analysis")
                            .foregroundStyle(AmberTheme.amberDark)
                    } else {
                        Text("Set up your API key in Settings first.")
                            .foregroundStyle(AmberTheme.cgaRed)
                    }
                }
            }
        )
    }

    @available(iOS 16.0, *)
    private var photosPickerButton: some View {
        PhotosPicker(selection: Binding(
            get: { selectedItem as? PhotosPickerItem },
            set: { selectedItem = $0 }
        ), matching: .images) {
            Label("Choose from Library", systemImage: "photo")
        }
        .onChange(of: selectedItem as? PhotosPickerItem) { item in
            guard let item = item else { return }
            handlePhotoSelection(item)
        }
    }

    // MARK: - Error

    private func errorSection(_ error: String) -> some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(AmberTheme.cgaRed)

                Text(error)
                    .font(DOSTypography.body)
                    .foregroundStyle(AmberTheme.cgaRed)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    store.dispatch(.setFoodAnalysisError(error: ""))
                    store.dispatch(.setFoodAnalysisLoading(isLoading: false))
                }
                .foregroundStyle(AmberTheme.amber)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Staging Plate Results

    private func resultsSection(_ result: NutritionEstimate) -> some View {
        Group {
            // Nutrition banner — auto-computed from plate items
            Section(
                content: {
                    if totalsOverridden {
                        macroRow(label: "Carbs", value: $overrideCarbs, unit: "g")
                        macroRow(label: "Protein", value: $overrideProtein, unit: "g")
                        macroRow(label: "Fat", value: $overrideFat, unit: "g")
                        macroRow(label: "Calories", value: $overrideCalories, unit: "kcal")
                        macroRow(label: "Fiber", value: $overrideFiber, unit: "g")

                        Button("Use auto-calculated totals") {
                            totalsOverridden = false
                        }
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                    } else {
                        HStack {
                            Text("\(Int(computedCarbs))g C")
                                .font(DOSTypography.body)
                                .foregroundStyle(AmberTheme.amber)
                            Spacer()
                            Button("Edit totals") {
                                overrideCarbs = computedCarbs
                                overrideProtein = result.totalProteinG
                                overrideFat = result.totalFatG
                                overrideCalories = result.totalCalories
                                overrideFiber = result.totalFiberG
                                totalsOverridden = true
                            }
                            .font(DOSTypography.caption)
                            .foregroundStyle(AmberTheme.amberDark)
                        }
                    }
                },
                header: {
                    Label("Nutrition", systemImage: "chart.bar")
                }
            )
            .onAppear {
                populateStagedItems(from: result)
            }

            // Meal details
            Section(
                content: {
                    HStack {
                        Text("Description")
                        TextField("", text: $editDescription)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        DatePicker("Time", selection: $editTimestamp, displayedComponents: [.date, .hourAndMinute])
                    }
                },
                header: {
                    Label("Meal", systemImage: "fork.knife")
                }
            )

            // Staging plate — editable food items
            Section(
                content: {
                    ForEach($stagedItems) { $item in
                        VStack(alignment: .leading, spacing: 4) {
                            // Summary row — tap to expand
                            HStack {
                                Text(item.name.isEmpty ? "New item" : item.name)
                                    .font(DOSTypography.body)
                                    .foregroundStyle(item.name.isEmpty ? AmberTheme.amberDark : AmberTheme.amber)
                                Spacer()
                                macroTag("\(Int(item.carbsG))g C", color: AmberTheme.amber)
                                Image(systemName: "chevron.right")
                                    .font(DOSTypography.caption)
                                    .foregroundStyle(AmberTheme.amberDark)
                                    .rotationEffect(item.isExpanded ? .degrees(90) : .zero)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.linear(duration: 0.2)) {
                                    item.isExpanded.toggle()
                                }
                            }

                            // Expanded edit fields
                            if item.isExpanded {
                                VStack(spacing: DOSSpacing.sm) {
                                    HStack {
                                        Text("Name")
                                            .font(DOSTypography.caption)
                                            .foregroundStyle(AmberTheme.amberDark)
                                        TextField("Food name", text: $item.name)
                                            .font(DOSTypography.body)
                                            .multilineTextAlignment(.trailing)
                                            .focused($focusedItemID, equals: item.id)
                                    }
                                    HStack {
                                        Text("Carbs")
                                            .font(DOSTypography.caption)
                                            .foregroundStyle(AmberTheme.amberDark)
                                        TextField("0", value: $item.carbsG, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 80)
                                        Text("g")
                                            .font(DOSTypography.caption)
                                            .foregroundStyle(AmberTheme.amberDark)
                                    }
                                }
                                .padding(.leading, DOSSpacing.md)
                            }
                        }
                    }
                    .onDelete { offsets in
                        focusedItemID = nil
                        stagedItems.remove(atOffsets: offsets)
                    }

                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                            .font(DOSTypography.body)
                            .foregroundStyle(AmberTheme.amber)
                    }
                },
                header: {
                    Label("Food items — tap to edit", systemImage: "list.bullet")
                }
            )

            // Confidence
            Section(
                content: {
                    confidenceRow(result.confidence)

                    if let notes = result.confidenceNotes {
                        Text(notes)
                            .font(DOSTypography.caption)
                            .foregroundStyle(AmberTheme.amberDark)
                    }
                },
                header: {
                    Label("Confidence", systemImage: "gauge")
                }
            )

            Section {
                Text("AI estimates are informational only. Consult your healthcare provider for medical decisions.")
                    .font(DOSTypography.caption)
                    .foregroundStyle(AmberTheme.amberDark)
            }

            Section {
                Button(action: saveAnalysis) {
                    HStack {
                        Spacer()
                        Text("Log Meal")
                            .font(DOSTypography.body)
                        Spacer()
                    }
                }
                .foregroundStyle(AmberTheme.amber)
            }
        }
    }

    private func populateStagedItems(from result: NutritionEstimate) {
        guard stagedItems.isEmpty else { return }
        editDescription = result.description
        stagedItems = result.items.map { item in
            EditableFoodItem(name: item.name, carbsG: item.carbsG)
        }
    }

    private func addItem() {
        let newItem = EditableFoodItem(name: "", carbsG: 0, isExpanded: true)
        stagedItems.append(newItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            focusedItemID = newItem.id
        }
    }

    private func macroRow(label: String, value: Binding<Double?>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("--", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .font(DOSTypography.caption)
                .foregroundStyle(AmberTheme.amberDark)
                .frame(width: 36, alignment: .leading)
        }
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(DOSTypography.caption)
            .foregroundStyle(color)
    }

    private func confidenceRow(_ confidence: NutritionEstimate.Confidence) -> some View {
        HStack {
            Text("Level")
            Spacer()
            switch confidence {
            case .high:
                Text("High")
                    .foregroundStyle(AmberTheme.cgaGreen)
            case .medium:
                Text("Medium")
                    .foregroundStyle(AmberTheme.amber)
            case .low:
                Text("Low")
                    .foregroundStyle(AmberTheme.cgaRed)
            }
        }
    }

    // MARK: - Actions

    @available(iOS 16.0, *)
    private func handlePhotoSelection(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { return }
            analyzeImage(image)
        }
    }

    private func analyzeImage(_ image: UIImage) {
        store.dispatch(.setFoodAnalysisLoading(isLoading: true))

        Task.detached {
            guard let imageData = image.preparedForVisionAPI() else {
                await MainActor.run {
                    store.dispatch(.setFoodAnalysisError(error: LocalizedString("Failed to prepare image.")))
                }
                return
            }

            await MainActor.run {
                store.dispatch(.analyzeFood(imageData: imageData))
            }
        }
    }

    private func saveAnalysis() {
        let trimmed = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let clampedDescription = String(trimmed.prefix(200))

        func clamp(_ value: Double?) -> Double? {
            value.flatMap { $0 >= 0 && $0 <= 10000 ? $0 : nil }
        }

        // Use overridden totals if user edited them, otherwise compute from items
        let finalCarbs = totalsOverridden ? clamp(overrideCarbs) : clamp(computedCarbs)
        let finalProtein = totalsOverridden ? clamp(overrideProtein) : nil
        let finalFat = totalsOverridden ? clamp(overrideFat) : nil
        let finalCalories = totalsOverridden ? clamp(overrideCalories) : nil
        let finalFiber = totalsOverridden ? clamp(overrideFiber) : nil

        // View creates the MealEntry (UUID ownership per learning)
        let meal = MealEntry(
            id: UUID(),
            timestamp: editTimestamp,
            mealDescription: clampedDescription,
            carbsGrams: finalCarbs,
            proteinGrams: finalProtein,
            fatGrams: finalFat,
            calories: finalCalories,
            fiberGrams: finalFiber
        )

        // Compute corrections by diffing staged items against original AI result
        let corrections = computeCorrections()

        // Single dispatch — middleware chains to .addMealEntry
        store.dispatch(.saveMealWithCorrections(meal: meal, corrections: corrections))
        store.dispatch(.setFoodAnalysisResult(result: nil))
        dismiss()
    }

    // MARK: - Correction Computation

    private func computeCorrections() -> [FoodCorrection] {
        guard let original = store.state.foodAnalysisResult else { return [] }

        var corrections: [FoodCorrection] = []
        let originalItems = original.items

        // Track which original items have been matched
        var matchedOriginalIndices = Set<Int>()

        // Match staged items to original items by position (best-effort)
        for (index, staged) in stagedItems.enumerated() {
            if index < originalItems.count {
                let orig = originalItems[index]
                matchedOriginalIndices.insert(index)

                let nameChanged = staged.name.lowercased() != orig.name.lowercased()
                let carbsChanged = abs(staged.carbsG - orig.carbsG) > 0.5

                if nameChanged && carbsChanged {
                    corrections.append(FoodCorrection(
                        correctionType: .nameChange,
                        originalName: orig.name,
                        correctedName: staged.name,
                        originalCarbsG: orig.carbsG,
                        correctedCarbsG: staged.carbsG
                    ))
                } else if nameChanged {
                    corrections.append(FoodCorrection(
                        correctionType: .nameChange,
                        originalName: orig.name,
                        correctedName: staged.name,
                        originalCarbsG: orig.carbsG,
                        correctedCarbsG: nil
                    ))
                } else if carbsChanged {
                    corrections.append(FoodCorrection(
                        correctionType: .carbChange,
                        originalName: orig.name,
                        correctedName: nil,
                        originalCarbsG: orig.carbsG,
                        correctedCarbsG: staged.carbsG
                    ))
                }
            } else {
                // Item added by user (not in original)
                corrections.append(FoodCorrection(
                    correctionType: .added,
                    originalName: nil,
                    correctedName: staged.name,
                    originalCarbsG: nil,
                    correctedCarbsG: staged.carbsG
                ))
            }
        }

        // Items in original that were deleted (not matched)
        for (index, orig) in originalItems.enumerated() {
            if !matchedOriginalIndices.contains(index) && index >= stagedItems.count {
                corrections.append(FoodCorrection(
                    correctionType: .deleted,
                    originalName: orig.name,
                    correctedName: nil,
                    originalCarbsG: orig.carbsG,
                    correctedCarbsG: nil
                ))
            }
        }

        return corrections
    }
}
