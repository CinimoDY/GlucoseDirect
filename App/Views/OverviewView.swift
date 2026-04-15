//
//  OverviewView.swift
//  DOSBTS
//

import SwiftUI

// MARK: - Active Sheet Enum (prevents iOS 15 sibling sheet collision)

private enum ActiveSheet: Identifiable {
    case insulin
    case meal
    case bloodGlucose
    case treatmentModal(alarmFiredAt: Date)
    case filteredFoodEntry
    case treatmentRecheck(glucoseValue: Int)

    var id: String {
        switch self {
        case .insulin: return "insulin"
        case .meal: return "meal"
        case .bloodGlucose: return "bloodGlucose"
        case .treatmentModal: return "treatmentModal"
        case .filteredFoodEntry: return "filteredFoodEntry"
        case .treatmentRecheck: return "treatmentRecheck"
        }
    }
}

struct OverviewView: View {
    @EnvironmentObject var store: DirectStore

    @State private var activeSheet: ActiveSheet?
    @State private var pendingSheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 0) {
            List {
                GlucoseView()
                    .listRowSeparator(.hidden)

                // Treatment countdown banner (between hero and chart)
                if store.state.treatmentCycleActive {
                    TreatmentBannerView()
                        .listRowSeparator(.hidden)
                }

                if !store.state.sensorGlucoseValues.isEmpty || !store.state.bloodGlucoseValues.isEmpty {
                    if #available(iOS 16.0, *) {
                        ChartView()
                    } else {
                        ChartViewCompatibility()
                    }
                }

                ConnectionView()
                SensorView()
            }.listStyle(.grouped)

            StickyQuickActions()
        }
        .sheet(item: $activeSheet, onDismiss: {
            // Present pending sheet after current one fully dismisses (avoids asyncAfter timing hack)
            if let pending = pendingSheet {
                pendingSheet = nil
                activeSheet = pending
            }
        }) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            // Handle cold launch: showTreatmentPrompt may already be true before onChange subscribes
            if store.state.showTreatmentPrompt, let alarmFiredAt = store.state.alarmFiredAt {
                activeSheet = .treatmentModal(alarmFiredAt: alarmFiredAt)
                store.dispatch(.setShowTreatmentPrompt(show: false))
            }
        }
        .onChange(of: store.state.showTreatmentPrompt) { newValue in
            if newValue, let alarmFiredAt = store.state.alarmFiredAt {
                activeSheet = .treatmentModal(alarmFiredAt: alarmFiredAt)
                store.dispatch(.setShowTreatmentPrompt(show: false))
            }
        }
        .onChange(of: store.state.recheckDispatched) { newValue in
            guard newValue, store.state.treatmentCycleActive else { return }
            // Check if still low — show recheck modal
            if let glucose = store.state.latestSensorGlucose,
               glucose.glucoseValue < store.state.alarmLow {
                activeSheet = .treatmentRecheck(glucoseValue: glucose.glucoseValue)
            }
            // If recovered, the banner handles the "STABILISED" state
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .insulin:
            AddInsulinView { start, end, units, insulinType in
                let insulinDelivery = InsulinDelivery(id: UUID(), starts: start, ends: end, units: units, type: insulinType)
                store.dispatch(.addInsulinDelivery(insulinDeliveryValues: [insulinDelivery]))
            }

        case .meal:
            UnifiedFoodEntryView()
                .environmentObject(store)

        case .bloodGlucose:
            AddBloodGlucoseView(glucoseUnit: store.state.glucoseUnit) { time, value in
                let glucose = BloodGlucose(id: UUID(), timestamp: time, glucoseValue: value)
                store.dispatch(.addBloodGlucose(glucoseValues: [glucose]))
            }

        case .treatmentModal(let alarmFiredAt):
            TreatmentModalView(
                alarmFiredAt: alarmFiredAt,
                onMoreTapped: {
                    // Set pending sheet — will be presented via onDismiss after this modal closes
                    pendingSheet = .filteredFoodEntry
                    activeSheet = nil
                }
            )
            .environmentObject(store)

        case .filteredFoodEntry:
            UnifiedFoodEntryView(filterToHypoTreatments: true)
                .environmentObject(store)

        case .treatmentRecheck(let glucoseValue):
            TreatmentModalView(
                alarmFiredAt: store.state.alarmFiredAt ?? Date(),
                onMoreTapped: {
                    pendingSheet = .filteredFoodEntry
                    activeSheet = nil
                },
                isRecheckMode: true,
                recheckGlucoseValue: glucoseValue
            )
            .environmentObject(store)
        }
    }

    // MARK: - Sticky Quick Actions

    @ViewBuilder
    private func StickyQuickActions() -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(AmberTheme.dosBorder)

            HStack(spacing: DOSSpacing.sm) {
                if DirectConfig.showInsulinInput, store.state.showInsulinInput {
                    QuickActionButton(
                        title: "INSULIN",
                        icon: "syringe",
                        action: { activeSheet = .insulin }
                    )
                }

                QuickActionButton(
                    title: "MEAL",
                    icon: "fork.knife",
                    action: { activeSheet = .meal }
                )
                .frame(maxWidth: .infinity)

                if DirectConfig.bloodGlucoseInput {
                    QuickActionButton(
                        title: "BG",
                        icon: "drop.fill",
                        action: { activeSheet = .bloodGlucose }
                    )
                }
            }
            .padding(.horizontal, DOSSpacing.md)
            .padding(.vertical, DOSSpacing.xs)
            .background(AmberTheme.dosBlack)
        }
    }
}

// MARK: - Quick Action Button

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DOSSpacing.xs) {
                Image(systemName: icon)
                    .font(DOSTypography.bodyLarge)
                    .frame(height: 20)
                Text(title)
                    .font(DOSTypography.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DOSSpacing.sm)
        }
        .buttonStyle(DOSButtonStyle(variant: .ghost))
        .frame(maxWidth: .infinity)
    }
}
