//
//  GlucoseWidget.swift
//  DOSBTSWidget
//

import SwiftUI
import WidgetKit

private let placeholderLowGlucose = SensorGlucose(timestamp: Date(), rawGlucoseValue: 70, intGlucoseValue: 80, minuteChange: 2)
private let placeholderGlucose = SensorGlucose(timestamp: Date(), rawGlucoseValue: 100, intGlucoseValue: 110, minuteChange: 5)
private let placeholderHighGlucose = SensorGlucose(timestamp: Date(), rawGlucoseValue: 400, intGlucoseValue: 410, minuteChange: 5)
private let placeholderGlucoseUnit = GlucoseUnit.mgdL

// MARK: - GlucoseEntry

struct GlucoseEntry: TimelineEntry {
    let date: Date
    let glucose: SensorGlucose?
    let glucoseUnit: GlucoseUnit?
    let alarmLow: Int
    let alarmHigh: Int
    let tir: Double?
    let iob: Double?
    let lastMealDescription: String?
    let lastMealCarbs: Double?
    let lastMealTimestamp: Date?
    let sparkline: [Int]?

    init() {
        self.date = Date()
        self.glucose = nil
        self.glucoseUnit = nil
        self.alarmLow = 70
        self.alarmHigh = 180
        self.tir = nil
        self.iob = nil
        self.lastMealDescription = nil
        self.lastMealCarbs = nil
        self.lastMealTimestamp = nil
        self.sparkline = nil
    }

    init(date: Date, glucose: SensorGlucose, glucoseUnit: GlucoseUnit) {
        self.date = date
        self.glucose = glucose
        self.glucoseUnit = glucoseUnit
        self.alarmLow = 70
        self.alarmHigh = 180
        self.tir = nil
        self.iob = nil
        self.lastMealDescription = nil
        self.lastMealCarbs = nil
        self.lastMealTimestamp = nil
        self.sparkline = nil
    }
}

// MARK: - GlucoseUpdateProvider

struct GlucoseUpdateProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseEntry {
        return GlucoseEntry(date: Date(), glucose: placeholderGlucose, glucoseUnit: placeholderGlucoseUnit)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseEntry) -> ()) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = buildEntry()
        let reloadDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(reloadDate))
        completion(timeline)
    }

    private func buildEntry() -> GlucoseEntry {
        let defaults = UserDefaults.shared
        var entry = GlucoseEntry()
        // Build expanded entry from shared UserDefaults
        return GlucoseEntry(
            date: Date(),
            glucose: defaults.latestSensorGlucose,
            glucoseUnit: defaults.glucoseUnit,
            alarmLow: defaults.alarmLow,
            alarmHigh: defaults.alarmHigh,
            tir: defaults.sharedTIR,
            iob: defaults.sharedIOB,
            lastMealDescription: defaults.sharedLastMealDescription,
            lastMealCarbs: defaults.sharedLastMealCarbs,
            lastMealTimestamp: defaults.sharedLastMealTimestamp,
            sparkline: defaults.sharedGlucoseSparkline
        )
    }
}

private extension GlucoseEntry {
    init(date: Date, glucose: SensorGlucose?, glucoseUnit: GlucoseUnit?, alarmLow: Int, alarmHigh: Int, tir: Double?, iob: Double?, lastMealDescription: String?, lastMealCarbs: Double?, lastMealTimestamp: Date?, sparkline: [Int]?) {
        self.date = date
        self.glucose = glucose
        self.glucoseUnit = glucoseUnit
        self.alarmLow = alarmLow
        self.alarmHigh = alarmHigh
        self.tir = tir
        self.iob = iob
        self.lastMealDescription = lastMealDescription
        self.lastMealCarbs = lastMealCarbs
        self.lastMealTimestamp = lastMealTimestamp
        self.sparkline = sparkline
    }
}

// MARK: - GlucoseView

struct GlucoseView: View {
    @Environment(\.widgetFamily) var size

    var entry: GlucoseEntry

    var glucoseUnit: GlucoseUnit? {
        entry.glucoseUnit ?? UserDefaults.shared.glucoseUnit
    }

    var glucose: SensorGlucose? {
        entry.glucose ?? UserDefaults.shared.latestSensorGlucose
    }

    private var staleness: DataStaleness {
        guard let glucose = glucose else { return .veryStale }
        return DataStaleness(since: glucose.timestamp)
    }

    private var isAlarm: Bool {
        guard let glucose = glucose else { return false }
        return glucose.glucoseValue < entry.alarmLow || glucose.glucoseValue > entry.alarmHigh
    }

    private var glucoseColor: Color {
        isAlarm ? WidgetColors.cgaRed : WidgetColors.amber
    }

    var body: some View {
        if let glucose, let glucoseUnit {
            switch size {
            case .accessoryCircular:
                circularView(glucose: glucose, glucoseUnit: glucoseUnit)

            case .accessoryRectangular:
                rectangularView(glucose: glucose, glucoseUnit: glucoseUnit)

            case .systemSmall:
                smallView(glucose: glucose, glucoseUnit: glucoseUnit)

            case .systemMedium:
                mediumView(glucose: glucose, glucoseUnit: glucoseUnit)

            case .systemLarge:
                largeView(glucose: glucose, glucoseUnit: glucoseUnit)

            default:
                Text("---")
                    .font(WidgetFonts.body)
                    .foregroundColor(WidgetColors.amberDark)
            }
        } else {
            noDataView
        }
    }

    // MARK: - No Data

    private var noDataView: some View {
        VStack(spacing: 4) {
            Text("---")
                .font(WidgetFonts.glucoseHero)
                .foregroundColor(WidgetColors.amberDark)
            Text("NO DATA")
                .font(WidgetFonts.caption)
                .foregroundColor(WidgetColors.amberDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(backgroundView: WidgetColors.dosBlack)
    }

    // MARK: - Lock Screen: Circular

    private func circularView(glucose: SensorGlucose, glucoseUnit: GlucoseUnit) -> some View {
        VStack(alignment: .center, spacing: 1) {
            Text(glucose.glucoseValue.asGlucose(glucoseUnit: glucoseUnit))
                .widgetAccentable()
                .font(WidgetFonts.mono(size: 24, weight: .bold))
                .bold()

            Text(glucose.trend.description)
                .font(WidgetFonts.mono(size: 14, weight: .bold))
        }
        .widgetBackground(backgroundView: Color("WidgetBackground"))
    }

    // MARK: - Lock Screen: Rectangular

    private func rectangularView(glucose: SensorGlucose, glucoseUnit: GlucoseUnit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(glucose.glucoseValue.asGlucose(glucoseUnit: glucoseUnit))
                    .widgetAccentable()
                    .bold()
                    .font(WidgetFonts.mono(size: 32, weight: .bold))

                Text(glucose.trend.description)
                    .font(WidgetFonts.mono(size: 18, weight: .bold))

                if let minuteChange = glucose.minuteChange?.asShortMinuteChange(glucoseUnit: glucoseUnit) {
                    Text(minuteChange)
                        .font(WidgetFonts.caption)
                }
            }

            HStack(spacing: 6) {
                if let tir = entry.tir {
                    Text("TIR \(Int(tir))%")
                }
                if let iob = entry.iob {
                    Text(String(format: "IOB %.1fU", iob))
                }
                Text(glucose.timestamp.toLocalTime())
            }
            .font(WidgetFonts.tabBar)
            .foregroundColor(.secondary)
        }
        .widgetBackground(backgroundView: Color("WidgetBackground"))
    }

    // MARK: - Home Screen: Small

    private func smallView(glucose: SensorGlucose, glucoseUnit: GlucoseUnit) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            // Glucose value
            if glucose.type != .high {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(verbatim: glucose.glucoseValue.asGlucose(glucoseUnit: glucoseUnit))
                        .font(WidgetFonts.glucoseHero)
                        .foregroundColor(glucoseColor)
                        .phosphorGlow(color: glucoseColor)
                        .opacity(staleness.glucoseOpacity)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: glucose.trend.description)
                            .font(WidgetFonts.mono(size: 18, weight: .bold))
                            .foregroundColor(glucoseColor)

                        if let minuteChange = glucose.minuteChange?.asShortMinuteChange(glucoseUnit: glucoseUnit) {
                            Text(verbatim: minuteChange)
                                .font(WidgetFonts.caption)
                                .foregroundColor(WidgetColors.amberDark)
                        }
                    }
                }
            } else {
                Text("HIGH")
                    .font(WidgetFonts.mono(size: 44, weight: .bold))
                    .foregroundColor(WidgetColors.cgaRed)
                    .phosphorGlow(color: WidgetColors.cgaRed)
            }

            Spacer(minLength: 0)

            // Timestamp
            Text(glucose.timestamp, style: .time)
                .font(WidgetFonts.caption)
                .monospacedDigit()
                .foregroundColor(staleness.timestampColor)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(backgroundView: WidgetColors.dosBlack)
    }

    // MARK: - Home Screen: Medium

    private func mediumView(glucose: SensorGlucose, glucoseUnit: GlucoseUnit) -> some View {
        HStack(spacing: 0) {
            // Left: Glucose
            VStack(spacing: 4) {
                Spacer(minLength: 0)

                if glucose.type != .high {
                    Text(verbatim: glucose.glucoseValue.asGlucose(glucoseUnit: glucoseUnit))
                        .font(WidgetFonts.glucoseLarge)
                        .foregroundColor(glucoseColor)
                        .phosphorGlow(color: glucoseColor)
                        .opacity(staleness.glucoseOpacity)

                    Text(verbatim: glucose.trend.description)
                        .font(WidgetFonts.mono(size: 22, weight: .bold))
                        .foregroundColor(glucoseColor)
                } else {
                    Text("HIGH")
                        .font(WidgetFonts.glucoseLarge)
                        .foregroundColor(WidgetColors.cgaRed)
                        .phosphorGlow(color: WidgetColors.cgaRed)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(WidgetColors.amberDark.opacity(0.4))
                .frame(width: 1)
                .padding(.vertical, 12)

            // Right: Stats
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)

                if let tir = entry.tir {
                    HStack(spacing: 4) {
                        Text("TIR")
                            .foregroundColor(WidgetColors.amberDark)
                        Text("\(Int(tir))%")
                            .foregroundColor(tir >= 70 ? WidgetColors.cgaGreen : WidgetColors.amber)
                    }
                    .font(WidgetFonts.label)
                }

                if let iob = entry.iob {
                    HStack(spacing: 4) {
                        Text("IOB")
                            .foregroundColor(WidgetColors.amberDark)
                        Text(String(format: "%.1fU", iob))
                            .foregroundColor(WidgetColors.cgaCyan)
                    }
                    .font(WidgetFonts.label)
                }

                if let meal = entry.lastMealDescription {
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 10))
                            .foregroundColor(WidgetColors.amberDark)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(meal)
                                .lineLimit(1)
                            if let carbs = entry.lastMealCarbs {
                                Text("\(Int(carbs))g")
                                    .foregroundColor(WidgetColors.amberDark)
                            }
                        }
                    }
                    .font(WidgetFonts.labelSmall)
                    .foregroundColor(WidgetColors.amber)
                }

                Spacer(minLength: 0)

                Text(glucose.timestamp, style: .time)
                    .font(WidgetFonts.caption)
                    .monospacedDigit()
                    .foregroundColor(staleness.timestampColor)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(backgroundView: WidgetColors.dosBlack)
    }

    // MARK: - Home Screen: Large

    private func largeView(glucose: SensorGlucose, glucoseUnit: GlucoseUnit) -> some View {
        VStack(spacing: 8) {
            // Top: Glucose + stats row
            HStack(alignment: .top) {
                // Glucose
                VStack(alignment: .leading, spacing: 2) {
                    if glucose.type != .high {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(verbatim: glucose.glucoseValue.asGlucose(glucoseUnit: glucoseUnit))
                                .font(WidgetFonts.glucoseLarge)
                                .foregroundColor(glucoseColor)
                                .phosphorGlow(color: glucoseColor)

                            Text(verbatim: glucose.trend.description)
                                .font(WidgetFonts.mono(size: 24, weight: .bold))
                                .foregroundColor(glucoseColor)
                        }
                    } else {
                        Text("HIGH")
                            .font(WidgetFonts.glucoseLarge)
                            .foregroundColor(WidgetColors.cgaRed)
                            .phosphorGlow(color: WidgetColors.cgaRed)
                    }
                }

                Spacer()

                // Stats column
                VStack(alignment: .trailing, spacing: 4) {
                    if let tir = entry.tir {
                        Text("TIR \(Int(tir))%")
                            .foregroundColor(tir >= 70 ? WidgetColors.cgaGreen : WidgetColors.amber)
                    }
                    if let iob = entry.iob {
                        Text(String(format: "IOB %.1fU", iob))
                            .foregroundColor(WidgetColors.cgaCyan)
                    }
                    if let carbs = entry.lastMealCarbs {
                        Text("\(Int(carbs))g")
                            .foregroundColor(WidgetColors.amber)
                    }
                }
                .font(WidgetFonts.label)
            }

            // Sparkline chart
            if let sparkline = entry.sparkline, sparkline.count >= 2 {
                GeometryReader { geo in
                    let result = SparklineBuilder.build(
                        values: sparkline,
                        in: CGRect(x: 0, y: 0, width: geo.size.width, height: geo.size.height),
                        alarmLow: entry.alarmLow,
                        alarmHigh: entry.alarmHigh
                    )

                    ZStack {
                        // Threshold lines
                        if let lowY = result.lowY {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: lowY))
                                path.addLine(to: CGPoint(x: geo.size.width, y: lowY))
                            }
                            .stroke(WidgetColors.cgaRed.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        if let highY = result.highY {
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: highY))
                                path.addLine(to: CGPoint(x: geo.size.width, y: highY))
                            }
                            .stroke(WidgetColors.cgaRed.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Sparkline
                        result.path
                            .stroke(WidgetColors.amber, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                            .shadow(color: WidgetColors.amber.opacity(0.4), radius: 3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            } else {
                // No sparkline data
                Rectangle()
                    .fill(WidgetColors.amberDark.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        Text("NO CHART DATA")
                            .font(WidgetFonts.caption)
                            .foregroundColor(WidgetColors.amberDark)
                    )
            }

            Spacer(minLength: 0)

            // Bottom: timestamp + sensor
            HStack {
                Text(glucose.timestamp, style: .time)
                    .monospacedDigit()
                    .foregroundColor(staleness.timestampColor)

                Spacer()

                if let sensorName = UserDefaults.shared.sharedSensor {
                    Text(sensorName)
                        .foregroundColor(WidgetColors.amberDark)
                }
            }
            .font(WidgetFonts.caption)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetBackground(backgroundView: WidgetColors.dosBlack)
    }
}

// MARK: - GlucoseWidget

struct GlucoseWidget: Widget {
    let kind: String = "GlucoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlucoseUpdateProvider()) { entry in
            GlucoseView(entry: entry)
        }
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .systemSmall, .systemMedium, .systemLarge])
        .configurationDisplayName("Glucose")
        .description("Real-time glucose with trend, TIR, IOB, and sparkline chart")
    }
}

// MARK: - GlucoseWidget_Previews

struct GlucoseWidget_Previews: PreviewProvider {
    static var previews: some View {
        GlucoseView(entry: GlucoseEntry(date: Date(), glucose: placeholderGlucose, glucoseUnit: .mgdL))
            .previewContext(WidgetPreviewContext(family: .systemSmall))

        GlucoseView(entry: GlucoseEntry(date: Date(), glucose: placeholderGlucose, glucoseUnit: .mgdL))
            .previewContext(WidgetPreviewContext(family: .systemMedium))

        GlucoseView(entry: GlucoseEntry(date: Date(), glucose: placeholderGlucose, glucoseUnit: .mgdL))
            .previewContext(WidgetPreviewContext(family: .systemLarge))

        GlucoseView(entry: GlucoseEntry(date: Date(), glucose: placeholderLowGlucose, glucoseUnit: .mgdL))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))

        GlucoseView(entry: GlucoseEntry(date: Date(), glucose: placeholderHighGlucose, glucoseUnit: .mgdL))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
