//
//  Widget.swift
//  DOSBTSApp
//

import ActivityKit
import Combine
import Foundation
import WidgetKit

func widgetCenterMiddleware() -> Middleware<DirectState, DirectAction> {
    widgetCenterMiddleware(service: LazyService<ActivityGlucoseService>(initialization: {
        ActivityGlucoseService()
    }))
}

/// Day/night alarm profile snapshot threaded through Live Activity ContentState.
/// Live Activity views compute the active profile at render time using these
/// values, avoiding push churn at the day/night boundary.
private struct AlarmProfilePayload {
    let dayAlarmHigh: Int
    let dayAlarmLow: Int
    let nightAlarmHigh: Int
    let nightAlarmLow: Int
    let nightStartHour: Int
    let nightStartMinute: Int
    let nightEndHour: Int
    let nightEndMinute: Int
}

private extension DirectState {
    var liveActivityAlarmProfilePayload: AlarmProfilePayload {
        AlarmProfilePayload(
            dayAlarmHigh: dayAlarmHigh,
            dayAlarmLow: dayAlarmLow,
            nightAlarmHigh: nightAlarmHigh,
            nightAlarmLow: nightAlarmLow,
            nightStartHour: nightStartHour,
            nightStartMinute: nightStartMinute,
            nightEndHour: nightEndHour,
            nightEndMinute: nightEndMinute
        )
    }
}

private func widgetCenterMiddleware(service: LazyService<ActivityGlucoseService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            guard state.glucoseLiveActivity else {
                break
            }

            // Pre-upgrade in-flight ContentStates use legacy alarmLow/alarmHigh as
            // a stable day-anchored fallback. We populate those from
            // dayAlarmHigh/dayAlarmLow (NOT the active-profile values) so the
            // legacy path stays predictable and doesn't oscillate at boundaries.
            service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)

        case .setGlucoseUnit(unit: _):
            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)
            }

        case .setGlucoseLiveActivity(enabled: let enabled):
            if enabled {
                guard service.value.isActivated else {
                    break
                }

                service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)
            } else {
                service.value.stop()
            }

        case .setAppState(appState: let appState):
            guard appState == .active else {
                break
            }
            
            WidgetCenter.shared.reloadAllTimelines()

            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.restartRecommended || service.value.startRequired {
                service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)
            }

        case .setConnectionState(connectionState: _):
            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)
            }

        case .setDayAlarmHigh, .setDayAlarmLow, .setDayAlarmVolume,
             .setNightAlarmHigh, .setNightAlarmLow, .setNightAlarmVolume,
             .setNightScheduleStart, .setNightScheduleEnd:
            // Push the schedule + per-profile thresholds into the in-flight Live
            // Activity ContentState so users see settings changes without waiting
            // for the next sensor tick.
            guard state.glucoseLiveActivity, service.value.isActivated, !service.value.startRequired else {
                break
            }
            service.value.update(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)

        case .addSensorGlucose(glucoseValues: _):
            // Home-screen widget reload. Critical that this fires from the
            // middleware (not the view layer) because SwiftUI .onChange
            // handlers don't run when the app is backgrounded, and new
            // sensor readings must refresh the widget on the home screen
            // regardless of scene state.
            WidgetCenter.shared.reloadAllTimelines()

            guard state.glucoseLiveActivity else {
                break
            }

            guard service.value.isActivated else {
                break
            }

            if service.value.stopRequired {
                service.value.stop()

            } else if service.value.restartRecommended || service.value.startRequired, state.appState == .active {
                service.value.start(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)

            } else if !service.value.startRequired {
                service.value.update(alarmLow: state.dayAlarmLow, alarmHigh: state.dayAlarmHigh, sensorState: state.sensor?.state, connectionState: state.connectionState, glucose: state.latestSensorGlucose, glucoseUnit: state.glucoseUnit, profile: state.liveActivityAlarmProfilePayload)
            }

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - ActivityGlucoseService

private class ActivityGlucoseService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create ActivityGlucoseService")
    }

    // MARK: Internal

    var isActivated: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var restartRecommended: Bool {
        if let activityRefresh = activityRestart, Date() > activityRefresh {
            return true
        }

        return false
    }

    var stopRequired: Bool {
        if let activityStop = activityStop, Date() > activityStop {
            return true
        }

        return false
    }

    var startRequired: Bool {
        return activity == nil
    }

    func start(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit, profile: AlarmProfilePayload) {
        Task {
            let activities = Activity<SensorGlucoseActivityAttributes>.activities
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            do {
                activityStart = Date()
                activityRestart = Date() + 5 * 60
                activityStop = Date() + 8 * 60 * 60

                let activityAttributes = SensorGlucoseActivityAttributes()
                let initialContentState = getStatus(alarmLow: alarmLow, alarmHigh: alarmHigh, sensorState: sensorState, connectionState: connectionState, glucose: glucose, glucoseUnit: glucoseUnit, profile: profile)

                activity = try Activity<SensorGlucoseActivityAttributes>.request(
                    attributes: activityAttributes,
                    content: ActivityContent(state: initialContentState, staleDate: nil),
                    pushType: nil
                )
            } catch {
                DirectLog.error("\(error)")

                activityStart = nil
                activityRestart = nil
                activityStop = nil
                activity = nil
            }
        }
    }

    func update(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit, profile: AlarmProfilePayload) {
        guard let activity = activity else {
            return
        }

        Task {
            let updatedStatus = getStatus(alarmLow: alarmLow, alarmHigh: alarmHigh, sensorState: sensorState, connectionState: connectionState, glucose: glucose, glucoseUnit: glucoseUnit, profile: profile)
            await activity.update(ActivityContent(state: updatedStatus, staleDate: nil))
        }
    }

    func stop() {
        activityStart = nil
        activityRestart = nil
        activityStop = nil
        activity = nil

        Task {
            let activities = Activity<SensorGlucoseActivityAttributes>.activities
            for activity in activities {
                await activity.end(ActivityContent(state: getStatus(), staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: Private

    private var activity: Activity<SensorGlucoseActivityAttributes>?
    private var activityStart: Date?
    private var activityRestart: Date?
    private var activityStop: Date?

    private func getStatus() -> SensorGlucoseActivityAttributes.GlucoseStatus {
        return SensorGlucoseActivityAttributes.GlucoseStatus(alarmLow: 0, alarmHigh: 0)
    }

    private func getStatus(alarmLow: Int, alarmHigh: Int, sensorState: SensorState?, connectionState: SensorConnectionState, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit, profile: AlarmProfilePayload) -> SensorGlucoseActivityAttributes.GlucoseStatus {
        return SensorGlucoseActivityAttributes.GlucoseStatus(
            alarmLow: alarmLow,
            alarmHigh: alarmHigh,
            sensorState: sensorState,
            connectionState: connectionState,
            glucose: glucose,
            glucoseUnit: glucoseUnit,
            iob: UserDefaults.shared.sharedIOB,
            sparkline: UserDefaults.shared.sharedGlucoseSparkline,
            startDate: activityStart,
            restartDate: activityRestart,
            stopDate: activityStop,
            nightStartHour: profile.nightStartHour,
            nightStartMinute: profile.nightStartMinute,
            nightEndHour: profile.nightEndHour,
            nightEndMinute: profile.nightEndMinute,
            dayAlarmHigh: profile.dayAlarmHigh,
            dayAlarmLow: profile.dayAlarmLow,
            nightAlarmHigh: profile.nightAlarmHigh,
            nightAlarmLow: profile.nightAlarmLow
        )
    }
}
