//
//  UserDefaultsAppState.swift
//  DOSBTS
//

import Combine
import Foundation
import SwiftUI
import UserNotifications

#if canImport(CoreNFC)
    import CoreNFC
#endif

// MARK: - AppState

struct AppState: DirectState {
    // MARK: Lifecycle

    init() {
        #if targetEnvironment(simulator)
            let defaultConnectionID = DirectConfig.virtualID
        #else
            #if canImport(CoreNFC)
                let defaultConnectionID = NFCTagReaderSession.readingAvailable
                    ? DirectConfig.libre2ID
                    : DirectConfig.bubbleID
            #else
                let defaultConnectionID = DirectConfig.bubbleID
            #endif
        #endif

        if UserDefaults.shared.glucoseUnit == nil {
            UserDefaults.shared.glucoseUnit = UserDefaults.standard.glucoseUnit ?? .mgdL
        }

        if let sensor = UserDefaults.standard.sensor, UserDefaults.shared.sensor == nil {
            UserDefaults.shared.sensor = sensor
        }

        if let transmitter = UserDefaults.standard.transmitter, UserDefaults.shared.transmitter == nil {
            UserDefaults.shared.transmitter = transmitter
        }

        // Day/Night alarm profile migration. Runs once when per-profile keys are absent.
        // Trigger condition: `dayAlarmHigh == nil` only — sufficient because dual-write keeps
        // the legacy `alarmHigh` key present forever after the first day-side edit, so adding
        // `&& alarmHigh != nil` would always be true and break re-run protection.
        if UserDefaults.standard.object(forKey: "libre-direct.settings.day-alarm-high") == nil {
            // If a legacy install exists, copy its values into both profiles. Otherwise the
            // UserDefaults computed accessors will return their built-in defaults (180/80/0.5)
            // when we read below.
            let legacyHigh = UserDefaults.standard.object(forKey: "libre-direct.settings.alarm-high") != nil
                ? UserDefaults.standard.alarmHigh : nil
            let legacyLow = UserDefaults.standard.object(forKey: "libre-direct.settings.alarm-low") != nil
                ? UserDefaults.standard.alarmLow : nil
            let legacyVolume = UserDefaults.standard.object(forKey: "libre-direct.settings.alarm-volume") != nil
                ? UserDefaults.standard.alarmVolume : nil

            UserDefaults.standard.dayAlarmHigh = legacyHigh ?? 180
            UserDefaults.standard.nightAlarmHigh = legacyHigh ?? 180
            UserDefaults.standard.dayAlarmLow = legacyLow ?? 80
            UserDefaults.standard.nightAlarmLow = legacyLow ?? 80
            UserDefaults.standard.dayAlarmVolume = legacyVolume ?? 0.5
            UserDefaults.standard.nightAlarmVolume = legacyVolume ?? 0.5
            UserDefaults.standard.nightStartHour = 22
            UserDefaults.standard.nightStartMinute = 0
            UserDefaults.standard.nightEndHour = 7
            UserDefaults.standard.nightEndMinute = 0
        }

        self.dayAlarmHigh = UserDefaults.standard.dayAlarmHigh
        self.dayAlarmLow = UserDefaults.standard.dayAlarmLow
        self.dayAlarmVolume = UserDefaults.standard.dayAlarmVolume
        self.nightAlarmHigh = UserDefaults.standard.nightAlarmHigh
        self.nightAlarmLow = UserDefaults.standard.nightAlarmLow
        self.nightAlarmVolume = UserDefaults.standard.nightAlarmVolume
        self.nightStartHour = UserDefaults.standard.nightStartHour
        self.nightStartMinute = UserDefaults.standard.nightStartMinute
        self.nightEndHour = UserDefaults.standard.nightEndHour
        self.nightEndMinute = UserDefaults.standard.nightEndMinute
        self.appleCalendarExport = UserDefaults.standard.appleCalendarExport
        self.appleHealthExport = UserDefaults.standard.appleHealthExport
        self.appleHealthImport = UserDefaults.standard.appleHealthImport
        self.healthImportExcludedSources = UserDefaults.standard.healthImportExcludedSources
        self.bellmanAlarm = UserDefaults.standard.bellmanAlarm
        self.chartShowLines = UserDefaults.standard.chartShowLines
        self.chartZoomLevel = UserDefaults.standard.chartZoomLevel
        self.connectionAlarmSound = UserDefaults.standard.connectionAlarmSound
        self.connectionPeripheralUUID = UserDefaults.standard.connectionPeripheralUUID
        self.customCalibration = UserDefaults.standard.customCalibration
        self.expiringAlarmSound = UserDefaults.standard.expiringAlarmSound
        self.normalGlucoseNotification = UserDefaults.standard.normalGlucoseNotification
        self.alarmGlucoseNotification = UserDefaults.standard.alarmGlucoseNotification
        self.glucoseLiveActivity = UserDefaults.standard.glucoseLiveActivity
        self.ignoreMute = UserDefaults.standard.ignoreMute
        self.glucoseUnit = UserDefaults.shared.glucoseUnit ?? .mgdL
        self.highGlucoseAlarmSound = UserDefaults.standard.highGlucoseAlarmSound
        self.isConnectionPaired = UserDefaults.standard.isConnectionPaired
        self.latestBloodGlucose = UserDefaults.shared.latestBloodGlucose
        self.latestSensorGlucose = UserDefaults.shared.latestSensorGlucose
        self.latestSensorError = UserDefaults.shared.latestSensorError
        self.latestInsulinDelivery = UserDefaults.shared.latestInsulinDelivery
        self.lowGlucoseAlarmSound = UserDefaults.standard.lowGlucoseAlarmSound
        self.nightscoutApiSecret = UserDefaults.standard.nightscoutApiSecret
        self.nightscoutUpload = UserDefaults.standard.nightscoutUpload
        self.nightscoutURL = UserDefaults.standard.nightscoutURL
        self.readGlucose = UserDefaults.standard.readGlucose
        self.selectedCalendarTarget = UserDefaults.standard.selectedCalendarTarget
        self.selectedConnectionID = UserDefaults.standard.selectedConnectionID ?? defaultConnectionID
        self.sensor = UserDefaults.shared.sensor
        self.sensorInterval = UserDefaults.standard.sensorInterval
        self.showAnnotations = UserDefaults.standard.showAnnotations
        self.transmitter = UserDefaults.shared.transmitter
        self.showSmoothedGlucose = UserDefaults.standard.showSmoothedGlucose
        self.showInsulinInput = UserDefaults.standard.showInsulinInput
        self.showScanlines = UserDefaults.standard.showScanlines
        self.aiConsentFoodPhoto = UserDefaults.standard.aiConsentFoodPhoto
        self.hasSeenBGRelocationHint = UserDefaults.standard.hasSeenBGRelocationHint
        self.appOpenCount = UserDefaults.standard.appOpenCount
        self.appOpenCountFirstRecordedAt = UserDefaults.standard.appOpenCountFirstRecordedAt
        self.aiConsentDailyDigest = UserDefaults.standard.aiConsentDailyDigest
        self.claudeAPIKeyValid = UserDefaults.standard.claudeAPIKeyValid
        self.thumbCalibrationMM = UserDefaults.standard.thumbCalibrationMM
        // Persist defaults on first launch so UUIDs are stable
        if UserDefaults.standard.data(forKey: "libre-direct.settings.serving-presets") == nil {
            UserDefaults.standard.servingPresets = ServingPreset.defaults
        }
        self.servingPresets = UserDefaults.standard.servingPresets
        self.treatmentCycleActive = UserDefaults.standard.treatmentCycleActive
        self.alarmFiredAt = UserDefaults.standard.alarmFiredAt
        self.treatmentLoggedAt = UserDefaults.standard.treatmentLoggedAt
        self.treatmentCycleCountdownExpiry = UserDefaults.standard.treatmentCycleCountdownExpiry
        self.treatmentCycleSnoozeUntil = UserDefaults.standard.treatmentCycleSnoozeUntil
        self.hypoTreatmentWaitMinutes = UserDefaults.standard.hypoTreatmentWaitMinutes
        self.showPredictiveLowAlarm = UserDefaults.standard.showPredictiveLowAlarm
        self.showHeartRateOverlay = UserDefaults.standard.showHeartRateOverlay
        self.markerLanePosition = UserDefaults.standard.markerLanePosition
        self.bolusInsulinPreset = UserDefaults.standard.bolusInsulinPreset
        self.basalDIAMinutes = UserDefaults.standard.basalDIAMinutes
        self.showSplitIOB = UserDefaults.standard.showSplitIOB
    }

    // MARK: Internal

    var appIsBusy = false
    var appState: ScenePhase = .inactive
    var alarmSnoozeUntil: Date? = nil
    var alarmSnoozeKind: Alarm?
    var bellmanConnectionState: BellmanConnectionState = .disconnected
    var bloodGlucoseHistory: [BloodGlucose] = []
    var bloodGlucoseValues: [BloodGlucose] = []
    var exerciseEntryValues: [ExerciseEntry] = []
    var heartRateSeries: [(Date, Double)] = []
    var healthImportExcludedSources: [String] { didSet { UserDefaults.standard.healthImportExcludedSources = healthImportExcludedSources } }
    var insulinDeliveryValues: [InsulinDelivery] = []
    var favoriteFoodValues: [FavoriteFood] = []
    var personalFoodValues: [PersonalFood] = []
    var recentFoodCorrections: [FoodCorrection] = []
    var recentMealEntries: [MealEntry] = []
    var mealEntryValues: [MealEntry] = []
    var connectionError: String?
    var connectionErrorTimestamp: Date?
    var connectionInfos: [SensorConnectionInfo] = []
    var connectionState: SensorConnectionState = .disconnected
    var preventScreenLock = false
    var selectedConnection: SensorConnectionProtocol?
    var selectedConfiguration: [SensorConnectionConfigurationOption] = []
    var minSelectedDate: Date = .init()
    var selectedDate: Date?
    var sensorErrorValues: [SensorError] = []
    var sensorGlucoseHistory: [SensorGlucose] = []
    var sensorGlucoseValues: [SensorGlucose] = []
    var glucoseStatistics: GlucoseStatistics?
    var targetValue = 100
    var selectedView = DirectConfig.overviewViewTag
    var statisticsDays = 3
   
    var appSerial: String {
        UserDefaults.shared.appSerial
    }

    // Day setters dual-write to legacy keys so a rollback to the prior binary
    // recovers to the user's day configuration. Night setters do not dual-write.
    var dayAlarmHigh: Int {
        didSet {
            UserDefaults.standard.dayAlarmHigh = dayAlarmHigh
            UserDefaults.standard.alarmHigh = dayAlarmHigh
        }
    }

    var dayAlarmLow: Int {
        didSet {
            UserDefaults.standard.dayAlarmLow = dayAlarmLow
            UserDefaults.standard.alarmLow = dayAlarmLow
        }
    }

    var dayAlarmVolume: Float {
        didSet {
            UserDefaults.standard.dayAlarmVolume = dayAlarmVolume
            UserDefaults.standard.alarmVolume = dayAlarmVolume
        }
    }

    var nightAlarmHigh: Int { didSet { UserDefaults.standard.nightAlarmHigh = nightAlarmHigh } }
    var nightAlarmLow: Int { didSet { UserDefaults.standard.nightAlarmLow = nightAlarmLow } }
    var nightAlarmVolume: Float { didSet { UserDefaults.standard.nightAlarmVolume = nightAlarmVolume } }
    var nightStartHour: Int { didSet { UserDefaults.standard.nightStartHour = nightStartHour } }
    var nightStartMinute: Int { didSet { UserDefaults.standard.nightStartMinute = nightStartMinute } }
    var nightEndHour: Int { didSet { UserDefaults.standard.nightEndHour = nightEndHour } }
    var nightEndMinute: Int { didSet { UserDefaults.standard.nightEndMinute = nightEndMinute } }
    var appleCalendarExport: Bool { didSet { UserDefaults.standard.appleCalendarExport = appleCalendarExport } }
    var appleHealthExport: Bool { didSet { UserDefaults.standard.appleHealthExport = appleHealthExport } }
    var appleHealthImport: Bool { didSet { UserDefaults.standard.appleHealthImport = appleHealthImport } }
    var bellmanAlarm: Bool { didSet { UserDefaults.standard.bellmanAlarm = bellmanAlarm } }
    var chartShowLines: Bool { didSet { UserDefaults.standard.chartShowLines = chartShowLines } }
    var chartZoomLevel: Int { didSet { UserDefaults.standard.chartZoomLevel = chartZoomLevel } }
    var connectionAlarmSound: NotificationSound { didSet { UserDefaults.standard.connectionAlarmSound = connectionAlarmSound } }
    var connectionPeripheralUUID: String? { didSet { UserDefaults.standard.connectionPeripheralUUID = connectionPeripheralUUID } }
    var customCalibration: [CustomCalibration] { didSet { UserDefaults.standard.customCalibration = customCalibration } }
    var expiringAlarmSound: NotificationSound { didSet { UserDefaults.standard.expiringAlarmSound = expiringAlarmSound } }
    var normalGlucoseNotification: Bool { didSet { UserDefaults.standard.normalGlucoseNotification = normalGlucoseNotification } }
    var alarmGlucoseNotification: Bool { didSet { UserDefaults.standard.alarmGlucoseNotification = alarmGlucoseNotification } }
    var glucoseLiveActivity: Bool { didSet { UserDefaults.standard.glucoseLiveActivity = glucoseLiveActivity } }
    var glucoseUnit: GlucoseUnit { didSet { UserDefaults.shared.glucoseUnit = glucoseUnit } }
    var highGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.highGlucoseAlarmSound = highGlucoseAlarmSound } }
    var ignoreMute: Bool { didSet { UserDefaults.standard.ignoreMute = ignoreMute } }
    var isConnectionPaired: Bool { didSet { UserDefaults.standard.isConnectionPaired = isConnectionPaired } }
    var latestBloodGlucose: BloodGlucose? { didSet { UserDefaults.shared.latestBloodGlucose = latestBloodGlucose } }
    var latestSensorError: SensorError? { didSet { UserDefaults.shared.latestSensorError = latestSensorError } }
    var latestSensorGlucose: SensorGlucose? { didSet { UserDefaults.shared.latestSensorGlucose = latestSensorGlucose } }
    var latestInsulinDelivery: InsulinDelivery? { didSet { UserDefaults.shared.latestInsulinDelivery = latestInsulinDelivery } }
    var lowGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.lowGlucoseAlarmSound = lowGlucoseAlarmSound } }
    var nightscoutApiSecret: String { didSet { UserDefaults.standard.nightscoutApiSecret = nightscoutApiSecret } }
    var nightscoutUpload: Bool { didSet { UserDefaults.standard.nightscoutUpload = nightscoutUpload } }
    var nightscoutURL: String { didSet { UserDefaults.standard.nightscoutURL = nightscoutURL } }
    var readGlucose: Bool { didSet { UserDefaults.standard.readGlucose = readGlucose } }
    var selectedCalendarTarget: String? { didSet { UserDefaults.standard.selectedCalendarTarget = selectedCalendarTarget } }
    var selectedConnectionID: String? { didSet { UserDefaults.standard.selectedConnectionID = selectedConnectionID } }
    var sensor: Sensor? { didSet { UserDefaults.shared.sensor = sensor } }
    var sensorInterval: Int { didSet { UserDefaults.standard.sensorInterval = sensorInterval } }
    var showAnnotations: Bool { didSet { UserDefaults.standard.showAnnotations = showAnnotations } }
    var transmitter: Transmitter? { didSet { UserDefaults.shared.transmitter = transmitter } }
    var showSmoothedGlucose: Bool { didSet { UserDefaults.standard.showSmoothedGlucose = showSmoothedGlucose } }
    var showInsulinInput: Bool { didSet { UserDefaults.standard.showInsulinInput = showInsulinInput } }
    var showScanlines: Bool { didSet { UserDefaults.standard.showScanlines = showScanlines } }
    var aiConsentFoodPhoto: Bool { didSet { UserDefaults.standard.aiConsentFoodPhoto = aiConsentFoodPhoto } }
    var hasSeenBGRelocationHint: Bool { didSet { UserDefaults.standard.hasSeenBGRelocationHint = hasSeenBGRelocationHint } }
    var appOpenCount: Int { didSet { UserDefaults.standard.appOpenCount = appOpenCount } }
    var appOpenCountFirstRecordedAt: Date? { didSet { UserDefaults.standard.appOpenCountFirstRecordedAt = appOpenCountFirstRecordedAt } }
    var claudeAPIKeyValid: Bool { didSet { UserDefaults.standard.claudeAPIKeyValid = claudeAPIKeyValid } }
    var thumbCalibrationMM: Double? { didSet { UserDefaults.standard.thumbCalibrationMM = thumbCalibrationMM } }
    var servingPresets: [ServingPreset] { didSet { UserDefaults.standard.servingPresets = servingPresets } }
    var foodAnalysisResult: NutritionEstimate?
    var foodAnalysisError: String?
    var foodAnalysisLoading = false

    // MARK: Treatment Cycle
    var treatmentCycleActive: Bool { didSet { UserDefaults.standard.treatmentCycleActive = treatmentCycleActive } }
    var showTreatmentPrompt: Bool = false
    var alarmFiredAt: Date? { didSet { UserDefaults.standard.alarmFiredAt = alarmFiredAt } }
    var treatmentLoggedAt: Date? { didSet { UserDefaults.standard.treatmentLoggedAt = treatmentLoggedAt } }
    var treatmentCycleCountdownExpiry: Date? { didSet { UserDefaults.standard.treatmentCycleCountdownExpiry = treatmentCycleCountdownExpiry } }
    var treatmentCycleSnoozeUntil: Date? { didSet { UserDefaults.standard.treatmentCycleSnoozeUntil = treatmentCycleSnoozeUntil } }
    var hypoTreatmentWaitMinutes: Int { didSet { UserDefaults.standard.hypoTreatmentWaitMinutes = hypoTreatmentWaitMinutes } }
    var recheckDispatched: Bool = false

    // MARK: Predictive Low Alarm
    var showPredictiveLowAlarm: Bool { didSet { UserDefaults.standard.showPredictiveLowAlarm = showPredictiveLowAlarm } }
    var predictiveLowAlarmFired: Bool = false

    // MARK: Heart Rate Overlay (DMNC-848)
    var showHeartRateOverlay: Bool { didSet { UserDefaults.standard.showHeartRateOverlay = showHeartRateOverlay } }

    // MARK: Marker Lane Position (DMNC-848 D7)
    var markerLanePosition: MarkerLanePosition { didSet { UserDefaults.standard.markerLanePosition = markerLanePosition } }

    // MARK: IOB
    var bolusInsulinPreset: InsulinPreset { didSet { UserDefaults.standard.bolusInsulinPreset = bolusInsulinPreset } }
    var basalDIAMinutes: Int { didSet { UserDefaults.standard.basalDIAMinutes = basalDIAMinutes } }
    var showSplitIOB: Bool { didSet { UserDefaults.standard.showSplitIOB = showSplitIOB } }
    var iobDeliveries: [InsulinDelivery] = []

    // MARK: Meal Impact
    var scoredMealEntryIds: Set<UUID> = []

    // MARK: Daily Digest
    var currentDailyDigest: DailyDigest?
    var dailyDigestLoading: Bool = false
    var dailyDigestInsightLoading: Bool = false
    var dailyDigestEvents: DailyDigestEvents?
    var aiConsentDailyDigest: Bool { didSet { UserDefaults.standard.aiConsentDailyDigest = aiConsentDailyDigest } }
}
