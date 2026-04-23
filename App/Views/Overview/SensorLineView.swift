//
//  SensorLineView.swift
//  DOSBTS
//

import SwiftUI

struct SensorLineView: View {
    @EnvironmentObject var store: DirectStore
    @State private var disconnectChipRevealed: Bool = false
    @State private var showingDisconnectAlert: Bool = false

    var body: some View {
        HStack(spacing: DOSSpacing.sm) {
            dotAndLabel

            Spacer()

            trailingContent
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleRowTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelString)
        .accessibilityHint(accessibilityHintString)
        .alert("Disconnect sensor?", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                store.dispatch(.disconnectConnection)
                disconnectChipRevealed = false
            }
        } message: {
            Text("You'll need to reconnect the sensor to resume glucose readings.")
        }
    }

    // MARK: - Row parts

    private var dotAndLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(labelText)
                .font(DOSTypography.caption)
                .foregroundColor(labelColor)
                .bold(isConnected)
        }
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch currentState {
        case .connected:
            if disconnectChipRevealed {
                Button {
                    showingDisconnectAlert = true
                } label: {
                    Text("DISCONNECT")
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amber)
                        .padding(.horizontal, DOSSpacing.sm)
                        .padding(.vertical, 3)
                        .overlay(
                            Rectangle().stroke(AmberTheme.amber, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        case .disconnected:
            Button {
                store.dispatch(.connectConnection)
            } label: {
                Text("CONNECT")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amber)
                    .padding(.horizontal, DOSSpacing.sm)
                    .padding(.vertical, 3)
                    .overlay(
                        Rectangle().stroke(AmberTheme.amber, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        case .noSensor:
            Text("SET UP")
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberDark)
                .padding(.horizontal, DOSSpacing.sm)
                .padding(.vertical, 3)
                .overlay(
                    Rectangle().stroke(AmberTheme.amberDark, lineWidth: 1)
                )
        case .error, .bluetoothOff, .transient, .unknown:
            EmptyView()
        }
    }

    // MARK: - State resolution

    private enum ResolvedState {
        case connected
        case disconnected
        case noSensor
        case error
        case bluetoothOff
        case transient  // connecting / scanning / pairing / warmup
        case unknown
    }

    private var currentState: ResolvedState {
        if store.state.connectionError != nil {
            return .error
        }
        if store.state.connectionState == .powerOff {
            return .bluetoothOff
        }
        if !store.state.hasSelectedConnection {
            return .noSensor
        }
        if store.state.connectionState == .connected {
            return .connected
        }
        if [.connecting, .scanning, .pairing].contains(store.state.connectionState) {
            return .transient
        }
        if store.state.connectionState == .disconnected {
            return .disconnected
        }
        return .unknown
    }

    private var isConnected: Bool { currentState == .connected }

    private var dotColor: Color {
        switch currentState {
        case .connected: return AmberTheme.cgaGreen
        case .transient: return AmberTheme.amberLight
        case .disconnected, .noSensor: return AmberTheme.amberDark
        case .error, .bluetoothOff: return AmberTheme.cgaRed
        case .unknown: return AmberTheme.amberDark
        }
    }

    private var labelColor: Color {
        switch currentState {
        case .connected: return AmberTheme.cgaGreen
        case .transient: return AmberTheme.amberLight
        case .disconnected, .noSensor: return AmberTheme.amberDark
        case .error, .bluetoothOff: return AmberTheme.cgaRed
        case .unknown: return AmberTheme.amberDark
        }
    }

    private var labelText: String {
        switch currentState {
        case .connected:
            if let sensor = store.state.sensor {
                return "CONNECTED · \(sensor.remainingLifetime.inTime) LEFT"
            }
            return "CONNECTED"
        case .transient:
            if let sensor = store.state.sensor, sensor.state == .starting, let warmup = sensor.remainingWarmupTime {
                return "WARMUP · \(warmup.inTime) LEFT"
            }
            switch store.state.connectionState {
            case .connecting: return "CONNECTING…"
            case .scanning: return "SCANNING…"
            case .pairing: return "PAIRING…"
            default: return "…"
            }
        case .disconnected: return "DISCONNECTED"
        case .noSensor: return "NO SENSOR"
        case .error: return "CONNECTION ERROR"
        case .bluetoothOff: return "BLUETOOTH OFF"
        case .unknown: return "—"
        }
    }

    // MARK: - Interaction

    private func handleRowTap() {
        switch currentState {
        case .connected:
            disconnectChipRevealed.toggle()
        case .bluetoothOff:
            if let url = URL(string: "App-Prefs:Bluetooth") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabelString: String {
        switch currentState {
        case .connected:
            if let sensor = store.state.sensor {
                return "Sensor connected, \(sensor.remainingLifetime.inTime) remaining"
            }
            return "Sensor connected"
        case .transient: return labelText.lowercased().capitalized
        case .disconnected: return "Sensor disconnected"
        case .noSensor: return "No sensor set up"
        case .error: return "Connection error"
        case .bluetoothOff: return "Bluetooth is off"
        case .unknown: return "Sensor state unknown"
        }
    }

    private var accessibilityHintString: String {
        switch currentState {
        case .connected:
            return disconnectChipRevealed ? "Double-tap the disconnect chip to disconnect" : "Double-tap to reveal disconnect"
        case .bluetoothOff: return "Double-tap to open iOS Bluetooth settings"
        default: return ""
        }
    }
}

struct SensorLineView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DOSSpacing.md) {
            SensorLineView()
                .environmentObject(DirectStore(initialState: AppState(), reducer: directReducer, middlewares: []))
        }
        .background(AmberTheme.dosBlack)
        .preferredColorScheme(.dark)
    }
}
