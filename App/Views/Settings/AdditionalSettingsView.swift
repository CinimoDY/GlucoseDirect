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
}
