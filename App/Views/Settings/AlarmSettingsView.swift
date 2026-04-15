//
//  AlarmSettingsView.swift
//  DOSBTS
//

import SwiftUI

// MARK: - AlarmSettingsView

struct AlarmSettingsView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore

    var body: some View {
        Section(
            content: {
                Picker("Low glucose alarm", selection: selectedLowGlucoseAlarmSound) {
                    ForEach(NotificationSound.allCases, id: \.rawValue) { info in
                        Text(info.localizedDescription)
                    }
                }.pickerStyle(.menu)

                Picker("High glucose alarm", selection: selectedHighGlucoseAlarmSound) {
                    ForEach(NotificationSound.allCases, id: \.rawValue) { info in
                        Text(info.localizedDescription)
                    }
                }.pickerStyle(.menu)

                Picker("Connection alarm", selection: selectedConnectionAlarmSound) {
                    ForEach(NotificationSound.allCases, id: \.rawValue) { info in
                        Text(info.localizedDescription)
                    }
                }.pickerStyle(.menu)

                Picker("Wearing time alarm", selection: selectedExpiringAlarmSound) {
                    ForEach(NotificationSound.allCases, id: \.rawValue) { info in
                        Text(info.localizedDescription)
                    }
                }.pickerStyle(.menu)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Alarm volume")
                        Spacer()
                        Text((store.state.alarmVolume * 100).asPercent())
                    }
                    
                    Slider(value: alarmVolume, in: 0...1, step: 0.05)
                }

                Toggle("Ignore mute", isOn: ignoreMute).toggleStyle(SwitchToggleStyle(tint: AmberTheme.amber))

                Picker("Treatment recheck", selection: selectedHypoTreatmentWaitMinutes) {
                    ForEach([10, 15, 20, 25, 30], id: \.self) { minutes in
                        Text("\(minutes) min")
                    }
                }.pickerStyle(.menu)
            },
            header: {
                Label("Alarm settings", systemImage: "alarm")
            },
            footer: {
                Text("Treatment recheck: time to wait before checking glucose after treating a low")
            }
        )
    }

    // MARK: Private

    private var ignoreMute: Binding<Bool> {
        Binding(
            get: { store.state.ignoreMute },
            set: { store.dispatch(.setIgnoreMute(enabled: $0)) }
        )
    }
    
    private var alarmVolume: Binding<Float> {
        Binding(
            get: { store.state.alarmVolume },
            set: {
                store.dispatch(.setAlarmVolume(volume: $0))
                
                if DirectNotifications.shared.isPlaying() {
                    DirectNotifications.shared.setVolume(volume: $0)
                } else {
                    DirectNotifications.shared.testSound(sound: .alarm, volume: $0)
                }
            }
        )
    }

    private var selectedHypoTreatmentWaitMinutes: Binding<Int> {
        Binding(
            get: { store.state.hypoTreatmentWaitMinutes },
            set: { store.dispatch(.setHypoTreatmentWaitMinutes(minutes: $0)) }
        )
    }

    private var selectedLowGlucoseAlarmSound: Binding<String> {
        Binding(
            get: { store.state.lowGlucoseAlarmSound.rawValue },
            set: {
                let sound = NotificationSound(rawValue: $0)!

                store.dispatch(.setLowGlucoseAlarmSound(sound: sound))
                DirectNotifications.shared.testSound(sound: sound, volume: store.state.alarmVolume)
            }
        )
    }

    private var selectedHighGlucoseAlarmSound: Binding<String> {
        Binding(
            get: { store.state.highGlucoseAlarmSound.rawValue },
            set: {
                let sound = NotificationSound(rawValue: $0)!

                store.dispatch(.setHighGlucoseAlarmSound(sound: sound))
                DirectNotifications.shared.testSound(sound: sound, volume: store.state.alarmVolume)
            }
        )
    }

    private var selectedConnectionAlarmSound: Binding<String> {
        Binding(
            get: { store.state.connectionAlarmSound.rawValue },
            set: {
                let sound = NotificationSound(rawValue: $0)!

                store.dispatch(.setConnectionAlarmSound(sound: sound))
                DirectNotifications.shared.testSound(sound: sound, volume: store.state.alarmVolume)
            }
        )
    }

    private var selectedExpiringAlarmSound: Binding<String> {
        Binding(
            get: { store.state.expiringAlarmSound.rawValue },
            set: {
                let sound = NotificationSound(rawValue: $0)!

                store.dispatch(.setExpiringAlarmSound(sound: sound))
                DirectNotifications.shared.testSound(sound: sound, volume: store.state.alarmVolume)
            }
        )
    }
}
