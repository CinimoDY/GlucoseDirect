//
//  SettingsView.swift
//  DOSBTS
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: DirectStore

    var body: some View {
        NavigationStack {
            List {
                Group {
                    NavigationLink {
                        SensorDetailView()
                    } label: {
                        Label("Sensor details", systemImage: "sensor.tag.radiowaves.forward.fill")
                    }

                    NavigationLink {
                        SettingsConnectionsView()
                    } label: {
                        Label("Connections", systemImage: "antenna.radiowaves.left.and.right")
                    }

                    SensorConnectorSettingsView()
                    SensorConnectionConfigurationView()

                    GlucoseSettingsView()
                    AlarmSettingsView()
                    InsulinSettingsView()

                    NightscoutSettingsView()
                    AppleExportSettingsView()

                    AISettingsView()
                    BellmanSettingsView()
                    CalibrationSettingsView()
                    AdditionalSettingsView()

                    AboutView()
                }
                .listRowBackground(AmberTheme.dosBlack)
                .listRowSeparatorTint(AmberTheme.amberDark.opacity(0.3))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AmberTheme.dosBlack)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AmberTheme.dosBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}
