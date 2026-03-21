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

    var body: some View {
        VStack(spacing: 0) {
            if let latestGlucose = store.state.latestSensorGlucose {
                HStack(alignment: .lastTextBaseline, spacing: 20) {
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

                        VStack(alignment: .leading) {
                            Text(verbatim: latestGlucose.trend.description)
                                .foregroundColor(getGlucoseColor(glucose: latestGlucose))
                                .font(DOSTypography.mono(size: 52, weight: .bold))

                            if let minuteChange = latestGlucose.minuteChange?.asMinuteChange(glucoseUnit: store.state.glucoseUnit) {
                                Text(verbatim: minuteChange)
                            } else {
                                Text(verbatim: "?")
                            }
                        }
                    } else {
                        Text("HIGH")
                            .font(DOSTypography.glucoseHero)
                            .foregroundColor(AmberTheme.cgaRed)
                            .dosGlowLarge(color: AmberTheme.cgaRed)
                    }
                }

                if let warning = warning {
                    Text(verbatim: warning)
                        .font(DOSTypography.bodySmall)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AmberTheme.cgaRed)
                        .foregroundColor(AmberTheme.dosBlack)
                } else {
                    HStack(spacing: 40) {
                        Text(latestGlucose.timestamp, style: .time)
                        Text(verbatim: store.state.glucoseUnit.localizedDescription)
                    }.opacity(0.5)
                }

            } else {
                Text("No Data")
                    .font(DOSTypography.mono(size: 52, weight: .bold))
                    .foregroundColor(AmberTheme.cgaRed)

                Text(Date(), style: .time)
                    .opacity(0.5)
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
            .padding(.top)
            .disabled(store.state.latestSensorGlucose == nil)
            .buttonStyle(.plain)
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

    private var isDangerouslyLow: Bool {
        guard let glucose = store.state.latestSensorGlucose else { return false }
        return glucose.glucoseValue < store.state.alarmLow
    }

    /// Gradient glucose color based on value:
    /// - 100 mg/dL = perfect green (cgaGreen)
    /// - 100-alarmHigh = gradual green → amber
    /// - alarmHigh+ = amber → red (proportional to how far over)
    /// - Below alarmLow = red (dangerously low)
    private func getGlucoseColor(glucose: any Glucose) -> Color {
        let value = Double(glucose.glucoseValue)
        let low = Double(store.state.alarmLow)
        let high = Double(store.state.alarmHigh)
        let perfect = 100.0

        // Dangerously low → red
        if value < low {
            return AmberTheme.cgaRed
        }

        // In range: interpolate green → amber
        if value <= high {
            if value <= perfect {
                // Below or at perfect → pure green
                return AmberTheme.cgaGreen
            }
            // perfect → high: green → amber
            let t = min((value - perfect) / (high - perfect), 1.0)
            return interpolateColor(from: AmberTheme.cgaGreen, to: AmberTheme.amber, t: t)
        }

        // Above high: amber → red (over ~60 mg/dL above threshold)
        let veryHighRange = 60.0
        let t = min((value - high) / veryHighRange, 1.0)
        return interpolateColor(from: AmberTheme.amber, to: AmberTheme.cgaRed, t: t)
    }

    /// Linear color interpolation in RGB space
    private func interpolateColor(from: Color, to: Color, t: Double) -> Color {
        let f = UIColor(from)
        let t2 = UIColor(to)
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        f.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        t2.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)

        let clamped = max(0, min(t, 1))
        return Color(
            red: Double(fr + (tr - fr) * CGFloat(clamped)),
            green: Double(fg + (tg - fg) * CGFloat(clamped)),
            blue: Double(fb + (tb - fb) * CGFloat(clamped))
        )
    }
}
