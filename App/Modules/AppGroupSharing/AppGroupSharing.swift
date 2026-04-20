//
//  FreeAPS.swift
//  DOSBTS
//

import Combine
import Foundation

func appGroupSharingMiddleware() -> Middleware<DirectState, DirectAction> {
    return appGroupSharingMiddleware(service: LazyService<AppGroupSharingService>(initialization: {
        AppGroupSharingService()
    }))
}

private func appGroupSharingMiddleware(service: LazyService<AppGroupSharingService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            service.value.clearAll()
            service.value.setApp(app: DirectConfig.appName, appVersion: "\(DirectConfig.appVersion) (\(DirectConfig.appBuild))")

        case .selectConnection(id: _, connection: _):
            service.value.clearAll()

        case .setConnectionState(connectionState: let connectionState):
            service.value.setConnectionState(value: connectionState.localizedDescription)

        case .setSensor(sensor: let sensor, keepDevice: _):
            service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)

        case .setTransmitter(transmitter: let transmitter):
            service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)

        case .disconnectConnection:
            service.value.clearGlucoseValues()

        case .pairConnection:
            service.value.clearGlucoseValues()

        case .addBloodGlucose(glucoseValues: let glucoseValues):
            if let sensor = state.sensor {
                service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)
            } else {
                service.value.setSensor(sensor: nil, sensorState: nil, sensorConnectionState: nil)
            }

            if let transmitter = state.transmitter {
                service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)
            } else {
                service.value.setTransmitter(transmitter: nil, transmitterBattery: nil, transmitterHardware: nil, transmitterFirmware: nil)
            }

            guard let glucose = glucoseValues.last else {
                break
            }

            service.value.addBloodGlucose(glucoseValues: [glucose])

        case .addSensorGlucose(glucoseValues: let glucoseValues):
            if let sensor = state.sensor {
                service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)
            } else {
                service.value.setSensor(sensor: nil, sensorState: nil, sensorConnectionState: nil)
            }

            if let transmitter = state.transmitter {
                service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)
            } else {
                service.value.setTransmitter(transmitter: nil, transmitterBattery: nil, transmitterHardware: nil, transmitterFirmware: nil)
            }

            guard let glucose = glucoseValues.last else {
                break
            }

            guard glucose.type != .high else {
                break
            }

            service.value.addSensorGlucose(glucoseValues: [glucose])

            // Widget expanded data: TIR, IOB, last meal, sparkline
            service.value.setWidgetData(
                tir: state.glucoseStatistics?.tir,
                iobDeliveries: state.iobDeliveries,
                bolusPreset: state.bolusInsulinPreset,
                basalDIAMinutes: state.basalDIAMinutes,
                lastMeal: state.mealEntryValues.last,
                glucoseValues: state.sensorGlucoseValues
            )

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - AppGroupSharingService

private class AppGroupSharingService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create AppGroupSharingService")
    }

    // MARK: Internal

    func clearGlucoseValues() {
        UserDefaults.shared.sharedGlucose = nil
        UserDefaults.shared.sharedTIR = nil
        UserDefaults.shared.sharedIOB = nil
        UserDefaults.shared.sharedLastMealDescription = nil
        UserDefaults.shared.sharedLastMealCarbs = nil
        UserDefaults.shared.sharedLastMealTimestamp = nil
        UserDefaults.shared.sharedGlucoseSparkline = nil
    }

    func clearOthers() {
        UserDefaults.shared.sharedSensor = nil
        UserDefaults.shared.sharedSensorState = nil
        UserDefaults.shared.sharedSensorConnectionState = nil
        UserDefaults.shared.sharedTransmitter = nil
        UserDefaults.shared.sharedTransmitterBattery = nil
        UserDefaults.shared.sharedTransmitterHardware = nil
        UserDefaults.shared.sharedTransmitterFirmware = nil
    }

    func clearAll() {
        clearGlucoseValues()
        clearOthers()
    }

    func setApp(app: String?, appVersion: String?) {
        UserDefaults.shared.sharedApp = app
        UserDefaults.shared.sharedAppVersion = appVersion
    }

    func setSensor(sensor: String?, sensorState: String?, sensorConnectionState: String?) {
        UserDefaults.shared.sharedSensor = sensor
        UserDefaults.shared.sharedSensorState = sensorState
        UserDefaults.shared.sharedSensorConnectionState = sensorConnectionState
    }

    func setConnectionState(value: String?) {
        UserDefaults.shared.sharedSensorConnectionState = value
    }

    func setTransmitter(transmitter: String?, transmitterBattery: String?, transmitterHardware: String?, transmitterFirmware: String?) {
        UserDefaults.shared.sharedTransmitter = transmitter
        UserDefaults.shared.sharedTransmitterBattery = transmitterBattery
        UserDefaults.shared.sharedTransmitterHardware = transmitterHardware
        UserDefaults.shared.sharedTransmitterFirmware = transmitterFirmware
    }

    func setWidgetData(
        tir: Double?,
        iobDeliveries: [InsulinDelivery],
        bolusPreset: InsulinPreset,
        basalDIAMinutes: Int,
        lastMeal: MealEntry?,
        glucoseValues: [SensorGlucose]
    ) {
        // TIR
        UserDefaults.shared.sharedTIR = tir

        // IOB
        if !iobDeliveries.isEmpty {
            let basalModel = ExponentialInsulinModel(
                actionDuration: Double(basalDIAMinutes) * 60,
                peakActivityTime: bolusPreset.model.peakActivityTime
            )
            let result = computeIOB(
                deliveries: iobDeliveries,
                bolusModel: bolusPreset.model,
                basalModel: basalModel
            )
            UserDefaults.shared.sharedIOB = result.total > 0.05 ? result.total : nil
        } else {
            UserDefaults.shared.sharedIOB = nil
        }

        // Last meal
        UserDefaults.shared.sharedLastMealDescription = lastMeal?.mealDescription
        UserDefaults.shared.sharedLastMealCarbs = lastMeal?.carbsGrams
        UserDefaults.shared.sharedLastMealTimestamp = lastMeal?.timestamp

        // Sparkline: sample glucose at ~30-min intervals over last 6h
        let sixHoursAgo = Date().addingTimeInterval(-6 * 60 * 60)
        let recentGlucose = glucoseValues.filter { $0.timestamp >= sixHoursAgo }
            .sorted { $0.timestamp < $1.timestamp }

        if recentGlucose.count >= 2 {
            let interval: TimeInterval = 30 * 60 // 30 minutes
            var sampled: [Int] = []
            var nextSampleTime = recentGlucose.first!.timestamp

            for glucose in recentGlucose {
                if glucose.timestamp >= nextSampleTime {
                    sampled.append(glucose.glucoseValue)
                    nextSampleTime = glucose.timestamp.addingTimeInterval(interval)
                }
            }
            // Always include the last point
            if let last = recentGlucose.last, sampled.last != last.glucoseValue {
                sampled.append(last.glucoseValue)
            }
            UserDefaults.shared.sharedGlucoseSparkline = sampled
        } else {
            UserDefaults.shared.sharedGlucoseSparkline = nil
        }
    }

    func addBloodGlucose(glucoseValues: [BloodGlucose]) {
        let sharedValues = glucoseValues
            .map { $0.toFreeAPS() }
            .compactMap { $0 }

        guard let sharedValuesJson = try? JSONSerialization.data(withJSONObject: sharedValues) else {
            return
        }

        UserDefaults.shared.sharedGlucose = sharedValuesJson
    }

    func addSensorGlucose(glucoseValues: [SensorGlucose]) {
        let sharedValues = glucoseValues
            .map { $0.toFreeAPS() }
            .compactMap { $0 }

        guard let sharedValuesJson = try? JSONSerialization.data(withJSONObject: sharedValues) else {
            return
        }

        UserDefaults.shared.sharedGlucose = sharedValuesJson
    }
}

private extension BloodGlucose {
    func toFreeAPS() -> [String: Any]? {
        let date = "/Date(" + Int64(floor(timestamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"

        let freeAPSGlucose: [String: Any] = [
            "Value": glucoseValue,
            "Trend": SensorTrend.unknown.toNightscoutTrend(),
            "DT": date,
            "direction": SensorTrend.unknown.toNightscoutDirection(),
            "from": DirectConfig.projectName
        ]

        return freeAPSGlucose
    }
}

private extension SensorGlucose {
    func toFreeAPS() -> [String: Any]? {
        let date = "/Date(" + Int64(floor(timestamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"

        let freeAPSGlucose: [String: Any] = [
            "Value": glucoseValue,
            "Trend": trend.toNightscoutTrend(),
            "DT": date,
            "direction": trend.toNightscoutDirection(),
            "from": DirectConfig.projectName
        ]

        return freeAPSGlucose
    }
}
