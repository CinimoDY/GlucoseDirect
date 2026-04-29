//
//  GlucoseView.swift
//  DOSBTS
//

import SwiftUI

// MARK: - GlucoseView

struct GlucoseView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore
    @State private var lowPulse = false
    @State private var iobResult = IOBResult(total: 0, mealSnackIOB: 0, correctionBasalIOB: 0)
    @State private var iobTimer: Timer?
    @State private var showingConnectDialog = false

    var body: some View {
        VStack(spacing: 0) {
            if let latestGlucose = store.state.latestSensorGlucose {
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    if latestGlucose.type != .high {
                        Text(verbatim: latestGlucose.glucoseValue.asGlucose(glucoseUnit: store.state.glucoseUnit))
                            .font(DOSTypography.glucoseHero)
                            .foregroundColor(getGlucoseColor(glucose: latestGlucose))
                            .dosGlowLarge(color: getGlucoseColor(glucose: latestGlucose))
                            .opacity(isDangerouslyLow ? (lowPulse ? 0.4 : 1.0) : 1.0)
                            .animation(isDangerouslyLow ?
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                                value: lowPulse
                            )
                            .onAppear { lowPulse = true }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: latestGlucose.trend.description)
                                .foregroundColor(getGlucoseColor(glucose: latestGlucose))
                                .font(DOSTypography.mono(size: 36, weight: .bold))

                            if let minuteChange = latestGlucose.minuteChange?.asMinuteChange(glucoseUnit: store.state.glucoseUnit) {
                                Text(verbatim: minuteChange)
                                    .font(DOSTypography.caption)
                            } else {
                                Text(verbatim: "?")
                                    .font(DOSTypography.caption)
                            }
                        }
                    } else {
                        Text("HIGH")
                            .font(DOSTypography.glucoseHero)
                            .foregroundColor(AmberTheme.cgaRed)
                            .dosGlowLarge(color: AmberTheme.cgaRed)
                    }
                }

                if let staleMinutes = staleMinutes {
                    HStack(spacing: DOSSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("\(staleMinutes) MIN AGO")
                    }
                    .font(DOSTypography.caption)
                    .foregroundColor(staleMinutes >= 15 ? AmberTheme.cgaRed : AmberTheme.amberDark)
                    .padding(.top, 2)
                }

                if let warning = warning {
                    Text(verbatim: warning)
                        .font(DOSTypography.bodySmall)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(AmberTheme.cgaRed)
                        .foregroundColor(AmberTheme.dosBlack)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            DirectNotifications.shared.hapticFeedback()
                            showingConnectDialog = true
                        }
                        .accessibilityLabel("\(warning), tap to reconnect")
                        .accessibilityHint("Opens reconnect options")
                } else {
                    Text(verbatim: store.state.glucoseUnit.localizedDescription)
                        .font(DOSTypography.caption)
                        .opacity(0.5)
                }

                if iobResult.total > 0 {
                    iobLabel
                }

            } else {
                Text("No Data")
                    .font(DOSTypography.mono(size: 42, weight: .bold))
                    .foregroundColor(AmberTheme.cgaRed)

                Text(verbatim: "---")
                    .font(DOSTypography.caption)
                    .opacity(0.5)

                if iobResult.total > 0 {
                    iobLabel
                }
            }

            HStack {
                Button(action: {
                    DirectNotifications.shared.hapticFeedback()
                    store.dispatch(.setPreventScreenLock(enabled: !store.state.preventScreenLock))
                }, label: {
                    if store.state.preventScreenLock {
                        Image(systemName: "lock.slash")
                        Text("No screen lock")
                    } else {
                        Text(verbatim: "")
                        Image(systemName: "lock")
                    }
                }).opacity(store.state.preventScreenLock ? 1 : 0.5)

                Spacer()

                if store.state.alarmSnoozeUntil != nil {
                    Button(action: {
                        DirectNotifications.shared.hapticFeedback()
                        store.dispatch(.setAlarmSnoozeUntil(untilDate: nil))
                    }, label: {
                        Image(systemName: "delete.forward")
                    }).padding(.trailing, 5)
                }

                Button(action: {
                    let date = (store.state.alarmSnoozeUntil ?? Date()).toRounded(on: 1, .minute)
                    let nextDate = Calendar.current.date(byAdding: .minute, value: 30, to: date)

                    DirectNotifications.shared.hapticFeedback()
                    store.dispatch(.setAlarmSnoozeUntil(untilDate: nextDate))
                }, label: {
                    if let alarmSnoozeUntil = store.state.alarmSnoozeUntil {
                        Text(verbatim: alarmSnoozeUntil.toLocalTime())
                        Image(systemName: "speaker.slash")
                    } else {
                        Text(verbatim: "")
                        Image(systemName: "speaker.wave.2")
                    }
                }).opacity(store.state.alarmSnoozeUntil == nil ? 0.5 : 1)
            }
            .padding(.top, DOSSpacing.xs)
            .disabled(store.state.latestSensorGlucose == nil)
            .buttonStyle(.plain)
        }
        .onChange(of: store.state.iobDeliveries.count) { refreshIOB() }
        .onChange(of: store.state.latestSensorGlucose?.timestamp) { refreshIOB() }
        .onChange(of: store.state.bolusInsulinPreset) { refreshIOB() }
        .onChange(of: store.state.basalDIAMinutes) { refreshIOB() }
        .confirmationDialog("Reconnect sensor?", isPresented: $showingConnectDialog, titleVisibility: .visible) {
            Button("Connect (BLE)") {
                DirectNotifications.shared.hapticFeedback()
                store.dispatch(.connectConnection)
            }
            Button("Scan Sensor (NFC)") {
                DirectNotifications.shared.hapticFeedback()
                store.dispatch(.pairConnection)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Connect: fast reconnect to the existing session. Scan: full NFC re-scan for a new or expired sensor.")
        }
        .onAppear {
            refreshIOB()
            iobTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                refreshIOB()
            }
        }
        .onDisappear {
            iobTimer?.invalidate()
            iobTimer = nil
        }
    }

    // MARK: Private

    private var warning: String? {
        if let sensor = store.state.sensor, sensor.state != .ready {
            return sensor.state.localizedDescription
        }

        if store.state.connectionState != .connected {
            return store.state.connectionState.localizedDescription
        }

        return nil
    }

    /// Returns minutes since last reading if >5 min stale, nil otherwise
    private var staleMinutes: Int? {
        guard let glucose = store.state.latestSensorGlucose else { return nil }
        let elapsed = Int(Date().timeIntervalSince(glucose.timestamp) / 60)
        return elapsed >= 5 ? elapsed : nil
    }

    @ViewBuilder
    private var iobLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("IOB")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(AmberTheme.amberDark)

            if store.state.showSplitIOB && (iobResult.mealSnackIOB > 0 || iobResult.correctionBasalIOB > 0) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatIOB(iobResult.mealSnackIOB))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AmberTheme.iobBolus)
                    Text("BOLUS")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(AmberTheme.iobBolus.opacity(0.7))
                }
                Text("·")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AmberTheme.amberDark.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatIOB(iobResult.correctionBasalIOB))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AmberTheme.iobBasal)
                    Text("BASAL")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(AmberTheme.iobBasal.opacity(0.7))
                }
            } else {
                Text(formatIOB(iobResult.total))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AmberTheme.iobBolus)
            }
        }
    }

    private func formatIOB(_ value: Double) -> String {
        String(format: "%.1fU", value)
    }

    private func refreshIOB() {
        let bolusModel = store.state.bolusInsulinPreset.model
        let basalModel = ExponentialInsulinModel(
            actionDuration: Double(store.state.basalDIAMinutes) * 60,
            peakActivityTime: 75 * 60
        )
        iobResult = computeIOB(
            deliveries: store.state.iobDeliveries,
            bolusModel: bolusModel,
            basalModel: basalModel
        )
    }

    private var isDangerouslyLow: Bool {
        guard let glucose = store.state.latestSensorGlucose else { return false }
        return glucose.glucoseValue < store.state.alarmLow
    }

    private func getGlucoseColor(glucose: any Glucose) -> Color {
        AmberTheme.glucoseColor(forValue: glucose.glucoseValue, low: store.state.alarmLow, high: store.state.alarmHigh)
    }
}
