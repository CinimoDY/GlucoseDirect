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
                // Sensor details — pushes full sensor controls screen
                NavigationLink {
                    SensorDetailView()
                } label: {
                    Label("Sensor details", systemImage: "sensor.tag.radiowaves.forward.fill")
                }

                // Sensor
                SensorConnectorSettingsView()
                SensorConnectionConfigurationView()

                // Glucose & Alarms
                Section {}.listRowBackground(Color.clear)
                GlucoseSettingsView()
                AlarmSettingsView()
                InsulinSettingsView()

                // Export
                Section {}.listRowBackground(Color.clear)
                NightscoutSettingsView()
                AppleExportSettingsView()

                // AI & Extras
                Section {}.listRowBackground(Color.clear)
                AISettingsView()
                BellmanSettingsView()
                CalibrationSettingsView()
                AdditionalSettingsView()

                // About
                Section {}.listRowBackground(Color.clear)
                AboutView()
            }
            .listStyle(.grouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
