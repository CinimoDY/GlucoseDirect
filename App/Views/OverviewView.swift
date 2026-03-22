//
//  OverviewView.swift
//  DOSBTS
//

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: DirectStore

    @State private var showingAddInsulinView = false
    @State private var showingUnifiedFoodEntry = false
    @State private var showingAddBloodGlucoseView = false

    var body: some View {
        VStack(spacing: 0) {
            List {
                GlucoseView()
                    .listRowSeparator(.hidden)

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
                        action: { showingAddInsulinView = true }
                    )
                    .sheet(isPresented: $showingAddInsulinView) {
                        AddInsulinView { start, end, units, insulinType in
                            let insulinDelivery = InsulinDelivery(id: UUID(), starts: start, ends: end, units: units, type: insulinType)
                            store.dispatch(.addInsulinDelivery(insulinDeliveryValues: [insulinDelivery]))
                        }
                    }
                }

                QuickActionButton(
                    title: "MEAL",
                    icon: "fork.knife",
                    action: { showingUnifiedFoodEntry = true }
                )
                .sheet(isPresented: $showingUnifiedFoodEntry) {
                    UnifiedFoodEntryView()
                        .environmentObject(store)
                }
                .frame(maxWidth: .infinity)

                if DirectConfig.bloodGlucoseInput {
                    QuickActionButton(
                        title: "BG",
                        icon: "drop.fill",
                        action: { showingAddBloodGlucoseView = true }
                    )
                    .sheet(isPresented: $showingAddBloodGlucoseView) {
                        AddBloodGlucoseView(glucoseUnit: store.state.glucoseUnit) { time, value in
                            let glucose = BloodGlucose(id: UUID(), timestamp: time, glucoseValue: value)
                            store.dispatch(.addBloodGlucose(glucoseValues: [glucose]))
                        }
                    }
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
