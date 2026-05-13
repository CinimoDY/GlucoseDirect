//
//  AdditionalSettings.swift
//  DOSBTSApp
//
//  Created by Reimar Metzen on 16.01.23.
//

import SwiftUI

struct AdditionalSettingsView: View {
    @EnvironmentObject var store: DirectStore
    
    var body: some View {
        Section(
            content: {
                if DirectConfig.showSmoothedGlucose {
                    Toggle("Show smoothed glucose", isOn: showSmoothedGlucose).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))
                }

                if DirectConfig.showInsulinInput {
                    Toggle("Show insulin input", isOn: showInsulinInput).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))
                }

                Toggle("CRT scanline overlay", isOn: showScanlines).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Keep screen awake", isOn: preventScreenLock).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))
                    Text("Prevents the device from auto-locking while monitoring. Resets automatically when the app is backgrounded.")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Chart event markers")
                    Picker("Chart event markers", selection: markerLanePosition) {
                        ForEach(MarkerLanePosition.allCases) { position in
                            Text(position.displayLabel).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Where the meal/insulin/exercise icons sit relative to the glucose chart.")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Daily digest reminder", isOn: dailyDigestReminderEnabled).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))

                    if store.state.dailyDigestReminderHour != nil, store.state.dailyDigestReminderMinute != nil {
                        DatePicker(
                            "Time",
                            selection: dailyDigestReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Text("Daily local notification that opens the Daily Digest tab.")
                        .font(DOSTypography.caption)
                        .foregroundStyle(AmberTheme.amberDark)
                }
                .padding(.vertical, 4)
            },
            header: {
                Label("Additional settings", systemImage: "gearshape")
            }
        )
    }

    private var preventScreenLock: Binding<Bool> {
        Binding(
            get: { store.state.preventScreenLock },
            set: { store.dispatch(.setPreventScreenLock(enabled: $0)) }
        )
    }

    private var showSmoothedGlucose: Binding<Bool> {
        Binding(
            get: { store.state.showSmoothedGlucose },
            set: { store.dispatch(.setShowSmoothedGlucose(enabled: $0)) }
        )
    }

    private var showInsulinInput: Binding<Bool> {
        Binding(
            get: { store.state.showInsulinInput },
            set: { store.dispatch(.setShowInsulinInput(enabled: $0)) }
        )
    }

    private var showScanlines: Binding<Bool> {
        Binding(
            get: { store.state.showScanlines },
            set: { store.dispatch(.setShowScanlines(enabled: $0)) }
        )
    }

    private var markerLanePosition: Binding<MarkerLanePosition> {
        Binding(
            get: { store.state.markerLanePosition },
            set: { store.dispatch(.setMarkerLanePosition(position: $0)) }
        )
    }

    private var dailyDigestReminderEnabled: Binding<Bool> {
        Binding(
            get: { store.state.dailyDigestReminderHour != nil && store.state.dailyDigestReminderMinute != nil },
            set: { enabled in
                if enabled {
                    // Default to 8 PM if no prior time stored.
                    let hour = store.state.dailyDigestReminderHour ?? 20
                    let minute = store.state.dailyDigestReminderMinute ?? 0
                    store.dispatch(.setDailyDigestReminderTime(hour: hour, minute: minute))
                } else {
                    store.dispatch(.setDailyDigestReminderTime(hour: nil, minute: nil))
                }
            }
        )
    }

    private var dailyDigestReminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = store.state.dailyDigestReminderHour ?? 20
                components.minute = store.state.dailyDigestReminderMinute ?? 0
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.dispatch(.setDailyDigestReminderTime(hour: components.hour, minute: components.minute))
            }
        )
    }
}
