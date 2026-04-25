//
//  GlucoseChartView.swift
//  DOSBTS
//

import Charts
import SwiftUI

// MARK: - ChartView

struct ChartView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore
    let selectedReportType: ReportType
    let onTapMarkerGroup: (ConsolidatedMarkerGroup) -> Void

    var body: some View {
        VStack(spacing: 0) {
            switch selectedReportType {
            case .glucose:
                GlucoseChartContent
            case .timeInRange:
                TimeInRangeContent
            case .statistics:
                StatisticsContent
            }
        }
    }

    // MARK: - Glucose Chart Content

    private var GlucoseChartContent: some View {
        VStack {
                    HStack {
                        Button(action: {
                            setSelectedDate(addDays: -1)
                        }, label: {
                            Image(systemName: "arrowshape.turn.up.backward")
                        }).opacity((store.state.selectedDate ?? Date()).startOfDay > store.state.minSelectedDate.startOfDay ? 0.5 : 0)

                        Spacer()

                        Group {
                            if let selectedDate = store.state.selectedDate {
                                Text(verbatim: selectedDate.toLocalDate())
                            } else {
                                Text("\(DirectConfig.lastChartHours.description) hours")
                            }
                        }
                        .monospacedDigit()
                        .onTapGesture {
                            store.dispatch(.setSelectedDate(selectedDate: nil))
                        }

                        Spacer()

                        Button(action: {
                            setSelectedDate(addDays: +1)
                        }, label: {
                            Image(systemName: "arrowshape.turn.up.forward")
                        }).opacity(store.state.selectedDate == nil ? 0 : 0.5)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        Text(store.state.glucoseUnit.localizedDescription)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(AmberTheme.amberMuted)
                        Spacer()
                        if store.state.showSplitIOB && !iobSeries.isEmpty {
                            iobLegendChip(color: AmberTheme.cgaCyan, label: "MEAL/SNACK")
                            iobLegendChip(color: AmberTheme.amberDark, label: "BASAL/CORR")
                        } else if !iobSeries.isEmpty {
                            iobLegendChip(color: AmberTheme.cgaCyan, label: "IOB")
                        }
                        if store.state.showHeartRateOverlay && !store.state.heartRateSeries.isEmpty {
                            iobLegendChip(color: AmberTheme.cgaMagenta, label: "HR")
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        ScrollViewReader { scrollViewProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    if store.state.markerLanePosition == .top {
                                        EventMarkerLaneView(
                                            markerGroups: markerGroups,
                                            totalWidth: max(0, screenWidth, seriesWidth),
                                            timeRange: (startMarker ?? Date())...(endMarker ?? Date()),
                                            scoredMealEntryIds: store.state.scoredMealEntryIds,
                                            onTapGroup: onTapMarkerGroup
                                        )
                                        .frame(width: max(0, screenWidth, seriesWidth), height: Config.markerLaneHeight)
                                        .id("lane-\(store.state.markerLanePosition.rawValue)")
                                    }

                                    ChartView
                                        .frame(width: max(0, screenWidth, seriesWidth), height: min(screenHeight, Config.chartHeight))
                                    .onChange(of: store.state.sensorGlucoseValues) {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.bloodGlucoseValues) {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.insulinDeliveryValues) {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.chartZoomLevel) {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy, force: true)

                                    }.onAppear {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onTapGesture(count: 2) {
                                        showUnsmoothedValues = !showUnsmoothedValues
                                    }

                                    if store.state.markerLanePosition == .bottom {
                                        EventMarkerLaneView(
                                            markerGroups: markerGroups,
                                            totalWidth: max(0, screenWidth, seriesWidth),
                                            timeRange: (startMarker ?? Date())...(endMarker ?? Date()),
                                            scoredMealEntryIds: store.state.scoredMealEntryIds,
                                            onTapGroup: onTapMarkerGroup
                                        )
                                        .frame(width: max(0, screenWidth, seriesWidth), height: Config.markerLaneHeight)
                                        .id("lane-\(store.state.markerLanePosition.rawValue)")
                                    }
                                } // VStack
                            }
                        }

                        if selectedSmoothSensorPoint != nil || selectedRawSensorPoint != nil || selectedBloodPoint != nil || selectedHeartRate != nil {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading) {
                                    if let selectedSensorPoint = selectedSmoothSensorPoint {
                                        VStack(alignment: .leading) {
                                            Text(selectedSensorPoint.time.toLocalDateTime())
                                            Text(selectedSensorPoint.info).bold()
                                        }
                                        .font(DOSTypography.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AmberTheme.amberLight)
                                        .foregroundColor(AmberTheme.dosBlack)
                                        .cornerRadius(0)
                                    }

                                    if let selectedRawPoint = selectedRawSensorPoint, showUnsmoothedValues, store.state.showSmoothedGlucose {
                                        VStack(alignment: .leading) {
                                            Text(selectedRawPoint.time.toLocalDateTime())
                                            Text(selectedRawPoint.info).bold()
                                        }
                                        .font(DOSTypography.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AmberTheme.amberDark)
                                        .foregroundColor(AmberTheme.dosBlack)
                                        .cornerRadius(0)
                                    }
                                }

                                if let selectedBloodPoint = selectedBloodPoint {
                                    HStack {
                                        Image(systemName: "drop.fill")

                                        VStack(alignment: .leading) {
                                            Text(selectedBloodPoint.time.toLocalDateTime())
                                            Text(selectedBloodPoint.info).bold()
                                        }
                                    }
                                    .font(DOSTypography.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AmberTheme.cgaRed)
                                    .foregroundColor(AmberTheme.dosBlack)
                                    .cornerRadius(0)
                                }

                                if let hr = selectedHeartRate, store.state.showHeartRateOverlay {
                                    HStack(spacing: 4) {
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 10))
                                        Text("\(hr) bpm").bold()
                                    }
                                    .font(DOSTypography.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(AmberTheme.cgaMagenta)
                                    .foregroundColor(AmberTheme.dosBlack)
                                    .cornerRadius(0)
                                }
                            }.opacity(0.75)
                        }
                    }
        }
    }

    // MARK: - Time In Range Content

    private var TimeInRangeContent: some View {
        VStack(spacing: DOSSpacing.md) {
            if let stats = store.state.glucoseStatistics {
                VStack(spacing: DOSSpacing.sm) {
                    TimeInRangeBar(label: "TAR", value: stats.tar, color: AmberTheme.cgaRed)
                    TimeInRangeBar(label: "TIR", value: stats.tir, color: AmberTheme.cgaGreen)
                    TimeInRangeBar(label: "TBR", value: stats.tbr, color: AmberTheme.cgaRed)
                }

                Text("\(stats.days) of \(stats.maxDays) days")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
            } else {
                Text("No statistics available")
                    .font(DOSTypography.bodySmall)
                    .foregroundColor(AmberTheme.amberDark)
            }
        }
        .padding(.vertical, DOSSpacing.sm)
    }

    private func TimeInRangeBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: DOSSpacing.sm) {
            Text(label)
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberDark)
                .frame(width: 30, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AmberTheme.amberMuted.opacity(0.3))
                        .frame(height: 16)

                    Rectangle()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(value / 100.0)), height: 16)
                }
            }
            .frame(height: 16)

            Text(String(format: "%.0f%%", value))
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberLight)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Statistics Content

    private var StatisticsContent: some View {
        VStack(spacing: DOSSpacing.sm) {
            if let stats = store.state.glucoseStatistics {
                StatRow(label: "AVG", value: String(format: "%.0f", stats.avg), unit: store.state.glucoseUnit.localizedDescription)
                StatRow(label: "SD", value: String(format: "%.1f", stats.stdev), unit: store.state.glucoseUnit.localizedDescription)
                StatRow(label: "CV", value: String(format: "%.1f%%", stats.cv), unit: "")
                StatRow(label: "GMI", value: String(format: "%.1f%%", stats.gmi), unit: "")
                StatRow(label: "READINGS", value: "\(stats.readings)", unit: "")

                Text("\(stats.days) of \(stats.maxDays) days")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
                    .padding(.top, DOSSpacing.xs)
            } else {
                Text("No statistics available")
                    .font(DOSTypography.bodySmall)
                    .foregroundColor(AmberTheme.amberDark)
            }
        }
        .padding(.vertical, DOSSpacing.sm)
    }

    private func StatRow(label: String, value: String, unit: String) -> some View {
        HStack {
            Text(label)
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberDark)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(DOSTypography.bodySmall)
                    .foregroundColor(AmberTheme.amberLight)
                if !unit.isEmpty {
                    Text(unit)
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amberDark)
                }
            }
        }
    }

    var ChartView: some View {
        Chart {
            RuleMark(y: .value("Minimum High", chartMinimum))
                .foregroundStyle(.clear)

            RectangleMark(
                yStart: .value("Low", alarmLow),
                yEnd: .value("High", alarmHigh)
            )
            .foregroundStyle(AmberTheme.cgaGreen.opacity(0.08))

            RuleMark(y: .value("Lower limit", alarmLow))
                .foregroundStyle(AmberTheme.cgaRed)
                .lineStyle(Config.ruleStyle)

            RuleMark(y: .value("Upper limit", alarmHigh))
                .foregroundStyle(AmberTheme.cgaRed)
                .lineStyle(Config.ruleStyle)

            ForEach(glucoseSegments) { segment in
                ForEach(segment.points) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Glucose", point.value),
                        series: .value("Series", segment.id)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(segment.color)
                    .lineStyle(Config.smoothLineStyle)
                }
            }

            // MARK: - Prediction projection line
            if let latest = store.state.latestSensorGlucose,
               let minuteChange = smoothedMinuteChange,
               Date().timeIntervalSince(latest.timestamp) < 5 * 60,
               store.state.selectedDate == nil
            {
                let currentGlucose = convertToRequired(mgdLValue: latest.glucoseValue)
                let predictedGlucose = currentGlucose + minuteChange * 20.0 * (store.state.glucoseUnit == .mmolL ? (1.0 / 18.0182) : 1.0)
                let endTime = latest.timestamp.addingTimeInterval(20 * 60)
                let predColor = AmberTheme.glucoseColor(forValue: Int(store.state.glucoseUnit == .mmolL ? predictedGlucose * 18.0182 : predictedGlucose), low: store.state.alarmLow, high: store.state.alarmHigh)

                LineMark(
                    x: .value("Time", latest.timestamp),
                    y: .value("Glucose", currentGlucose),
                    series: .value("Series", "prediction")
                )
                .foregroundStyle(predColor)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                LineMark(
                    x: .value("Time", endTime),
                    y: .value("Glucose", predictedGlucose),
                    series: .value("Series", "prediction")
                )
                .foregroundStyle(predColor)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                // Threshold crossing marker when prediction crosses alarmLow
                if minuteChange < 0 {
                    let currentMgdL = Double(latest.glucoseValue)
                    let alarmLowMgdL = Double(store.state.alarmLow)
                    if currentMgdL > alarmLowMgdL {
                        let minutesToCross = (alarmLowMgdL - currentMgdL) / minuteChange
                        if minutesToCross > 0, minutesToCross <= 20 {
                            let crossingTime = latest.timestamp.addingTimeInterval(minutesToCross * 60)
                            PointMark(
                                x: .value("Time", crossingTime),
                                y: .value("Glucose", alarmLow)
                            )
                            .symbol(.cross)
                            .symbolSize(80)
                            .foregroundStyle(AmberTheme.cgaRed)
                        }
                    }
                }
            }

            ForEach(bloodGlucoseSeries) { value in
                PointMark(
                    x: .value("Time", value.time),
                    y: .value("Glucose", value.value)
                )
                .symbolSize(Config.symbolSize)
                .foregroundStyle(AmberTheme.cgaRed)
            }

            ForEach(insulinSeries.filter { $0.type == .basal }) { value in
                RectangleMark(
                    xStart: .value("Starts", value.starts),
                    xEnd: .value("Ends", value.ends),
                    yStart: .value("Units", 0),
                    yEnd: .value("Units", value.value.map(from: 0...20, to: 0...Double(alarmLow)))
                )
                .opacity(0.25)
                .annotation(position: .overlay, alignment: .bottom) {
                    Text(value.value.asInsulin())
                        .foregroundStyle(AmberTheme.amberDark)
                        .padding(.horizontal, 2.5)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(2)
                        .bold()
                        .font(DOSTypography.caption)
                }
                .foregroundStyle(AmberTheme.amberDark)
            }

            // MARK: - IOB decay curve
            if !iobSeries.isEmpty {
                let maxIOB = iobSeries.map(\.total).max() ?? 1.0
                let iobCeiling = max(maxIOB, 1.0)

                if store.state.showSplitIOB {
                    // Bottom layer: meal/snack IOB (cyan)
                    ForEach(Array(iobSeries.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.date),
                            yStart: .value("Bottom", 0),
                            yEnd: .value("Meal+Snack IOB", point.mealSnack.map(from: 0...iobCeiling, to: 0...Double(alarmLow)))
                        )
                        .foregroundStyle(AmberTheme.cgaCyan.opacity(0.4))
                        .interpolationMethod(.monotone)
                    }

                    // Top layer: basal+correction IOB stacked above meal/snack (amber-dark)
                    ForEach(Array(iobSeries.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.date),
                            yStart: .value("Meal+Snack IOB", point.mealSnack.map(from: 0...iobCeiling, to: 0...Double(alarmLow))),
                            yEnd: .value("Total IOB", point.total.map(from: 0...iobCeiling, to: 0...Double(alarmLow)))
                        )
                        .foregroundStyle(AmberTheme.amberDark.opacity(0.55))
                        .interpolationMethod(.monotone)
                    }
                } else {
                    ForEach(Array(iobSeries.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("IOB", point.total.map(from: 0...iobCeiling, to: 0...Double(alarmLow)))
                        )
                        .foregroundStyle(AmberTheme.cgaCyan.opacity(0.3))
                        .interpolationMethod(.monotone)
                    }
                }
            }

            ForEach(exerciseSeries) { exercise in
                RectangleMark(
                    xStart: .value("Start", exercise.startTime),
                    xEnd: .value("End", exercise.endTime),
                    yStart: .value("Bottom", chartMinimum),
                    yEnd: .value("Top", chartMinimum * 0.95)
                )
                .foregroundStyle(AmberTheme.cgaCyan.opacity(0.3))
            }

            if store.state.showHeartRateOverlay {
                ForEach(store.state.heartRateSeries.indices, id: \.self) { index in
                    let point = store.state.heartRateSeries[index]
                    LineMark(
                        x: .value("Time", point.0),
                        y: .value("HR", scaledHR(point.1)),
                        series: .value("Series", "HeartRate")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                if let last = store.state.heartRateSeries.last,
                   Date().timeIntervalSince(last.0) < 10 * 60 {
                    PointMark(
                        x: .value("Time", last.0),
                        y: .value("HR", scaledHR(last.1))
                    )
                    .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.7))
                    .symbolSize(30)
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("\(Int(last.1))")
                            .font(DOSTypography.caption)
                            .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.7))
                    }
                }
            }

            if showUnsmoothedValues, store.state.showSmoothedGlucose {
                if !rawSensorGlucoseSeries.isEmpty {
                    ForEach(rawSensorGlucoseSeries) { value in
                        LineMark(
                            x: .value("Time", value.time),
                            y: .value("Glucose", value.value),
                            series: .value("Series", "Raw")
                        )
                        .interpolationMethod(.monotone)
                        .opacity(0.5)
                        .foregroundStyle(AmberTheme.amberDark)
                        .lineStyle(Config.rawLineStyle)
                    }
                }

                if let selectedPointInfo = selectedRawSensorPoint {
                    PointMark(
                        x: .value("Time", selectedPointInfo.time),
                        y: .value("Glucose", selectedPointInfo.value)
                    )
                    //.symbol(.square)
                    .opacity(0.75)
                    .symbolSize(Config.selectionSize)
                    .foregroundStyle(AmberTheme.amberDark)
                }
            }

            if let selectedPointInfo = selectedSmoothSensorPoint {
                PointMark(
                    x: .value("Time", selectedPointInfo.time),
                    y: .value("Glucose", selectedPointInfo.value)
                )
                .opacity(0.75)
                .symbolSize(Config.selectionSize)
                .foregroundStyle(AmberTheme.amberLight)
            }

            if let selectedPointInfo = selectedBloodPoint {
                PointMark(
                    x: .value("Time", selectedPointInfo.time),
                    y: .value("Glucose", selectedPointInfo.value)
                )
                //.symbol(.square)
                .opacity(0.75)
                .symbolSize(Config.selectionSize)
                .foregroundStyle(AmberTheme.cgaRed)
            }

            if let endMarker = endMarker {
                RuleMark(
                    x: .value("", endMarker)
                ).foregroundStyle(.clear)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: labelEvery)) { _ in
                AxisGridLine(stroke: Config.axisStyle)
                AxisTick(length: 4, stroke: Config.tickStyle)
                    .foregroundStyle(AmberTheme.amberMuted)
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .narrow)), anchor: .top)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .stride(by: yAxisSteps)) { value in
                AxisGridLine(stroke: Config.axisStyle)

                if let glucoseValue = value.as(Double.self), glucoseValue > 0 {
                    AxisTick(length: 4, stroke: Config.tickStyle)
                        .foregroundStyle(AmberTheme.amberMuted)
                    AxisValueLabel()
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                }
            }
        }
        .chartLegend(.hidden)
        .id(Config.chartID)
        .onChange(of: store.state.showSmoothedGlucose) {
            if shouldRefresh {
                DirectLog.info("onChange: sensorGlucoseValues")

                debounceSeriesMetadata()
                updateSensorSeries()
            }

        }.onChange(of: store.state.sensorGlucoseValues) {
            if shouldRefresh {
                DirectLog.info("onChange: sensorGlucoseValues")

                debounceSeriesMetadata()
                updateSensorSeries()
                updateSmoothedMinuteChange()
            }

        }.onChange(of: store.state.bloodGlucoseValues) {
            if shouldRefresh {
                DirectLog.info("onChange: bloodGlucoseValues")

                debounceSeriesMetadata()
                updateBloodSeries()
            }

        }.onChange(of: store.state.insulinDeliveryValues) {
            if shouldRefresh {
                DirectLog.info("onChange: insulinDeliveryValues")

                debounceSeriesMetadata()
                updateInsulinSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.iobDeliveries.count) {
            if shouldRefresh {
                DirectLog.info("onChange: iobDeliveries")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.bolusInsulinPreset) {
            if shouldRefresh {
                DirectLog.info("onChange: bolusInsulinPreset")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.basalDIAMinutes) {
            if shouldRefresh {
                DirectLog.info("onChange: basalDIAMinutes")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.mealEntryValues) {
            if shouldRefresh {
                DirectLog.info("onChange: mealEntryValues")

                debounceSeriesMetadata()
                updateMealSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.exerciseEntryValues) {
            if shouldRefresh {
                DirectLog.info("onChange: exerciseEntryValues")

                debounceSeriesMetadata()
                updateExerciseSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.chartZoomLevel) {
            if shouldRefresh {
                DirectLog.info("onChange: chartZoomLevel")

                debounceSeriesMetadata()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.showSmoothedGlucose) {
            showUnsmoothedValues = false

        }.onChange(of: store.state.selectedDate) {
            selectedSmoothSensorPoint = nil
            selectedRawSensorPoint = nil
            selectedBloodPoint = nil
            selectedHeartRate = nil

        }.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: orientation")

                debounceSeriesMetadata()
            }

        }.onAppear {
            DirectLog.info("onAppear")

            updateSeriesMetadata()
            updateSensorSeries()
            updateBloodSeries()
            updateInsulinSeries()
            updateMealSeries()
            updateExerciseSeries()
            updateHeartRateLookup()
            updateSmoothedMinuteChange()
            updateMarkerGroups()

        }.chartOverlay { overlayProxy in
            GeometryReader { geometryProxy in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let currentX = value.location.x - geometryProxy[overlayProxy.plotAreaFrame].origin.x

                            if let currentDate: Date = overlayProxy.value(atX: currentX) {
                                let rounded = currentDate.toRounded(on: 1, .minute)
                                let selectedSmoothSensorPoint = smoothSensorPointInfos[rounded]
                                let selectedRawSensorPoint = rawSensorPointInfos[rounded]
                                let selectedBloodPoint = bloodPointInfos[rounded]

                                if let selectedSmoothSensorPoint {
                                    self.selectedSmoothSensorPoint = selectedSmoothSensorPoint
                                }

                                self.selectedRawSensorPoint = selectedRawSensorPoint
                                self.selectedBloodPoint = selectedBloodPoint

                                // Search nearby minutes for heart rate (HR samples may not align exactly).
                                // Skip when the overlay is disabled — keeps the HR chip in the tooltip
                                // hidden and avoids the lookup work on every drag tick.
                                if store.state.showHeartRateOverlay {
                                    self.selectedHeartRate = nearestHeartRate(at: rounded)
                                }
                            }
                        }
                        .onEnded { dragValue in
                            let wasTap = abs(dragValue.translation.width) < 10 && abs(dragValue.translation.height) < 10

                            selectedSmoothSensorPoint = nil
                            selectedRawSensorPoint = nil
                            selectedBloodPoint = nil
                            selectedHeartRate = nil

                            guard wasTap else { return }
                        }
                    )
            }
        }
    }

    // MARK: Private

    private enum Config {
        static let chartID = "chart"
        static let cornerRadius: CGFloat = 20
        static let rangeCornerRadius: CGFloat = 2
        static let insulinSize: MarkDimension = 10
        static let symbolSize: CGFloat = 20
        static let selectionSize: CGFloat = 100
        static let mealSymbolSize: CGFloat = 120
        static let insulinSymbolSizeRange: ClosedRange<Double> = 30...160
        static let spacerWidth: CGFloat = 50
        static let chartHeight: CGFloat = 250
        static let lineStyle: StrokeStyle = .init(lineWidth: 3, lineCap: .round)
        static let smoothLineStyle: StrokeStyle = .init(lineWidth: 3.5, lineCap: .round)
        static let rawLineStyle: StrokeStyle = .init(lineWidth: 3, lineCap: .round)
        static let ruleStyle: StrokeStyle = .init(lineWidth: 1, dash: [2])
        static let gridStyle: StrokeStyle = .init(lineWidth: 1)
        static let dayStyle: StrokeStyle = .init(lineWidth: 1)
        static let axisStyle: StrokeStyle = .init(lineWidth: 0.3, dash: [2, 3])
        static let tickStyle: StrokeStyle = .init(lineWidth: 4)
        static let zoomLevels: [ZoomLevel] = [
            ZoomLevel(level: 3, name: LocalizedString("3h"), visibleHours: 3, labelEvery: 1),
            ZoomLevel(level: 6, name: LocalizedString("6h"), visibleHours: 6, labelEvery: 2),
            ZoomLevel(level: 12, name: LocalizedString("12h"), visibleHours: 12, labelEvery: 3),
            ZoomLevel(level: 24, name: LocalizedString("24h"), visibleHours: 24, labelEvery: 4)
        ]
        static let markerLaneHeight: CGFloat = 48
        static let consolidationWindows: [Int: TimeInterval] = [
            3: 0,
            6: 10 * 60,
            12: 20 * 60,
            24: 30 * 60
        ]
    }

    @State private var showUnsmoothedValues: Bool = false

    @State private var seriesWidth: CGFloat = 0
    @State private var smoothSensorGlucoseSeries: [GlucoseDatapoint] = []
    @State private var glucoseSegments: [GlucoseSegment] = []
    @State private var rawSensorGlucoseSeries: [GlucoseDatapoint] = []
    @State private var bloodGlucoseSeries: [GlucoseDatapoint] = []
    @State private var insulinSeries: [InsulinDatapoint] = []
    @State private var mealSeries: [MealDatapoint] = []
    @State private var exerciseSeries: [ExerciseDatapoint] = []
    @State private var iobSeries: [(date: Date, total: Double, mealSnack: Double, corrBasal: Double)] = []

    @State private var smoothSensorPointInfos: [Date: GlucoseDatapoint] = [:]
    @State private var rawSensorPointInfos: [Date: GlucoseDatapoint] = [:]
    @State private var bloodPointInfos: [Date: GlucoseDatapoint] = [:]

    @State private var selectedSmoothSensorPoint: GlucoseDatapoint? = nil
    @State private var selectedRawSensorPoint: GlucoseDatapoint? = nil
    @State private var selectedBloodPoint: GlucoseDatapoint? = nil
    @State private var selectedHeartRate: Int? = nil
    @State private var heartRatePointInfos: [Date: Int] = [:]

    @State private var markerGroups: [ConsolidatedMarkerGroup] = []

    @State private var smoothedMinuteChange: Double? = nil

    private let calculationQueue = DispatchQueue(label: "libre-direct.chart-calculation", qos: .utility)

    @State private var metadataDebounceTask: DispatchWorkItem? = nil

    private func debounceSeriesMetadata() {
        metadataDebounceTask?.cancel()
        let task = DispatchWorkItem { updateSeriesMetadata() }
        metadataDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: task)
    }

    private var screenHeight: CGFloat {
        UIScreen.screenHeight
    }

    private var screenWidth: CGFloat {
        // Clamp to 0: pre-scene cold launch returns 0 for UIScreen.screenWidth,
        // and 0 - 40 = -40 would cache into seriesWidth @State and stick there.
        max(0, UIScreen.screenWidth - 40)
    }

    private var yAxisSteps: Double {
        if store.state.glucoseUnit == .mmolL {
            return 3
        }

        return 50
    }

    private var zoomLevel: ZoomLevel? {
        if let zoomLevel = Config.zoomLevels.first(where: { $0.level == store.state.chartZoomLevel }) {
            return zoomLevel
        }

        return Config.zoomLevels.first
    }

    private var labelEvery: Int {
        if let zoomLevel = zoomLevel {
            return zoomLevel.labelEvery
        }

        return 1
    }

    private var chartMinimum: Double {
        if store.state.glucoseUnit == .mmolL {
            return 18
        }

        return 300
    }

    private var alarmLow: Double {
        convertToRequired(mgdLValue: store.state.alarmLow)
    }

    private var alarmHigh: Double {
        convertToRequired(mgdLValue: store.state.alarmHigh)
    }

    private func scaledHR(_ bpm: Double) -> Double {
        ((bpm - 40) / (200 - 40)) * (chartMinimum - alarmHigh) + alarmHigh
    }

    private func iobLegendChip(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color.opacity(0.55))
                .frame(width: 10, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
        }
    }

    private var startMarker: Date? {
        return firstTimestamp
    }

    private var endMarker: Date? {
        if let lastTimestamp = lastTimestamp, store.state.selectedDate == nil {
            if let zoomLevel = zoomLevel, zoomLevel.level == 1 {
                return Calendar.current.date(byAdding: .minute, value: 15, to: lastTimestamp)
            }

            return Calendar.current.date(byAdding: .hour, value: 1, to: lastTimestamp)
        }

        return lastTimestamp
    }

    private var shouldRefresh: Bool {
        store.state.appState == .active
    }

    private var firstTimestamp: Date? {
        let dates = [store.state.sensorGlucoseValues.first?.timestamp, store.state.bloodGlucoseValues.first?.timestamp]
            .compactMap { $0 }
            .sorted(by: { $0 < $1 })

        return dates.first
    }

    private var lastTimestamp: Date? {
        let dates = [store.state.sensorGlucoseValues.last?.timestamp, store.state.bloodGlucoseValues.last?.timestamp]
            .compactMap { $0 }
            .sorted(by: { $0 > $1 })

        return dates.first
    }

    private func convertToRequired(mgdLValue: Int) -> Double {
        if store.state.glucoseUnit == .mmolL {
            return mgdLValue.toMmolL()
        }

        return mgdLValue.toDouble()
    }

    private func setSelectedDate(addDays: Int) {
        // store.dispatch(.setChartZoomLevel(level: 24))
        store.dispatch(.setSelectedDate(selectedDate: Calendar.current.date(byAdding: .day, value: +addDays, to: store.state.selectedDate ?? Date())))

        DirectNotifications.shared.hapticFeedback()
    }

    private func scrollToStart(scrollViewProxy: ScrollViewProxy, force: Bool = false) {
        scrollTo(scrollViewProxy: scrollViewProxy, force: force, anchor: .leading)
    }

    private func scrollToEnd(scrollViewProxy: ScrollViewProxy, force: Bool = false) {
        scrollTo(scrollViewProxy: scrollViewProxy, force: force, anchor: .trailing)
    }

    private func scrollTo(scrollViewProxy: ScrollViewProxy, force: Bool = false, anchor: UnitPoint) {
        if selectedSmoothSensorPoint == nil || force {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                scrollViewProxy.scrollTo(Config.chartID, anchor: anchor)
            }

            if force {
                selectedSmoothSensorPoint = nil
                selectedRawSensorPoint = nil
                selectedBloodPoint = nil
            }
        }
    }

    private func updateSeriesMetadata() {
        DirectLog.info("updateSeriesMetadata()")

        if let firstTimestamp = firstTimestamp,
           let lastTimestamp = lastTimestamp,
           let zoomLevel = zoomLevel
        {
            let minuteWidth = (screenWidth / CGFloat(zoomLevel.visibleHours * 60))
            let chartMinutes = CGFloat((lastTimestamp.timeIntervalSince1970 - firstTimestamp.timeIntervalSince1970) / 60)
            let seriesWidth = CGFloat(minuteWidth * chartMinutes)

            if self.seriesWidth != seriesWidth {
                self.seriesWidth = seriesWidth
            }
        }
    }

    private func updateSensorSeries() {
        DirectLog.info("updateSensorSeries()")

        calculationQueue.async {
            var smoothSensorPointInfos: [Date: GlucoseDatapoint] = [:]
            var rawSensorPointInfos: [Date: GlucoseDatapoint] = [:]

            let smoothSensorGlucoseSeries = DirectConfig.showSmoothedGlucose && store.state.showSmoothedGlucose
                ? populateSmoothValues(glucoseValues: store.state.sensorGlucoseValues)
                : populateValues(glucoseValues: store.state.sensorGlucoseValues)
            smoothSensorGlucoseSeries.forEach { value in
                if smoothSensorPointInfos[value.time] == nil {
                    smoothSensorPointInfos[value.time] = value
                }
            }

            let rawSensorGlucoseSeries = store.state.showSmoothedGlucose
                ? populateValues(glucoseValues: store.state.sensorGlucoseValues.filter {
                    $0.timestamp < store.state.smoothThreshold
                })
                : []
            rawSensorGlucoseSeries.forEach { value in
                if rawSensorPointInfos[value.time] == nil {
                    rawSensorPointInfos[value.time] = value
                }
            }

            let segments = segmentGlucoseSeries(smoothSensorGlucoseSeries)

            DispatchQueue.main.async {
                self.smoothSensorGlucoseSeries = smoothSensorGlucoseSeries
                self.glucoseSegments = segments
                self.smoothSensorPointInfos = smoothSensorPointInfos

                self.rawSensorGlucoseSeries = rawSensorGlucoseSeries
                self.rawSensorPointInfos = rawSensorPointInfos
            }
        }
    }

    private func updateBloodSeries() {
        DirectLog.info("updateBloodSeries()")

        calculationQueue.async {
            var bloodPointInfos: [Date: GlucoseDatapoint] = [:]
            let bloodGlucoseSeries = populateValues(glucoseValues: store.state.bloodGlucoseValues)
            bloodGlucoseSeries.forEach { value in
                if bloodPointInfos[value.time] == nil {
                    bloodPointInfos[value.time] = value
                }
            }

            DispatchQueue.main.async {
                self.bloodGlucoseSeries = bloodGlucoseSeries
                self.bloodPointInfos = bloodPointInfos
            }
        }
    }

    private func updateInsulinSeries() {
        DirectLog.info("updateInsulinSeries()")

        calculationQueue.async {
            let insulinSeries = populateValues(glucoseValues: store.state.insulinDeliveryValues)

            // Compute IOB decay curve
            let bolusModel = store.state.bolusInsulinPreset.model
            let basalModel = ExponentialInsulinModel(
                actionDuration: Double(store.state.basalDIAMinutes) * 60,
                peakActivityTime: 75 * 60
            )
            let iobDeliveries = store.state.iobDeliveries

            var iobPoints: [(date: Date, total: Double, mealSnack: Double, corrBasal: Double)] = []

            if !iobDeliveries.isEmpty, let first = firstTimestamp, let last = lastTimestamp {
                let step: TimeInterval = 5 * 60 // 5-minute intervals
                var current = first
                while current <= last {
                    let result = computeIOB(
                        deliveries: iobDeliveries,
                        bolusModel: bolusModel,
                        basalModel: basalModel,
                        at: current
                    )
                    iobPoints.append((date: current, total: result.total, mealSnack: result.mealSnackIOB, corrBasal: result.correctionBasalIOB))
                    current = current.addingTimeInterval(step)
                }
            }

            DispatchQueue.main.async {
                self.insulinSeries = insulinSeries
                self.iobSeries = iobPoints
            }
        }
    }

    private func updateMealSeries() {
        DirectLog.info("updateMealSeries()")
        self.mealSeries = store.state.mealEntryValues.map { $0.toDatapoint() }
    }

    private func updateExerciseSeries() {
        DirectLog.info("updateExerciseSeries()")
        self.exerciseSeries = store.state.exerciseEntryValues.map { $0.toDatapoint() }
    }

    private func updateMarkerGroups() {
        let window = Config.consolidationWindows[store.state.chartZoomLevel] ?? 0
        var allMarkers: [EventMarker] = []

        for meal in store.state.mealEntryValues {
            let label: String
            if let carbs = meal.carbsGrams {
                label = "\(Int(carbs))g"
            } else {
                label = String(meal.mealDescription.prefix(6))
            }
            allMarkers.append(EventMarker(
                id: "meal-\(meal.id.uuidString)",
                time: meal.timestamp,
                type: .meal,
                label: label,
                rawValue: meal.carbsGrams ?? 0,
                sourceID: meal.id
            ))
        }

        for insulin in store.state.insulinDeliveryValues where insulin.type != .basal {
            allMarkers.append(EventMarker(
                id: "insulin-\(insulin.id.uuidString)",
                time: insulin.starts,
                type: .bolus,
                label: insulin.units.asInsulin(),
                rawValue: insulin.units,
                sourceID: insulin.id
            ))
        }

        for exercise in store.state.exerciseEntryValues {
            let mins = Int(exercise.durationMinutes)
            allMarkers.append(EventMarker(
                id: "exercise-\(exercise.id.uuidString)",
                time: exercise.startTime,
                type: .exercise,
                label: "\(mins)m",
                rawValue: Double(mins),
                sourceID: exercise.id
            ))
        }

        allMarkers.sort { $0.time < $1.time }

        // Consolidate into groups based on zoom-level window
        var groups: [ConsolidatedMarkerGroup] = []
        var currentMarkers: [EventMarker] = []

        for marker in allMarkers {
            if let last = currentMarkers.last, window > 0, marker.time.timeIntervalSince(last.time) > window {
                // New group
                if !currentMarkers.isEmpty {
                    let midTime = currentMarkers[currentMarkers.count / 2].time
                    groups.append(ConsolidatedMarkerGroup(
                        id: "group-\(currentMarkers[0].id)",
                        time: midTime,
                        markers: currentMarkers
                    ))
                }
                currentMarkers = [marker]
            } else {
                currentMarkers.append(marker)
            }
        }
        if !currentMarkers.isEmpty {
            let midTime = currentMarkers[currentMarkers.count / 2].time
            groups.append(ConsolidatedMarkerGroup(
                id: "group-\(currentMarkers[0].id)",
                time: midTime,
                markers: currentMarkers
            ))
        }

        markerGroups = groups
    }

    private func updateSmoothedMinuteChange() {
        let recentWithChange = store.state.sensorGlucoseValues.suffix(10).filter { $0.minuteChange != nil }
        let last3 = recentWithChange.suffix(3)
        guard !last3.isEmpty else {
            smoothedMinuteChange = nil
            return
        }
        let sum = last3.compactMap(\.minuteChange).reduce(0, +)
        smoothedMinuteChange = sum / Double(last3.count)
    }

    private func updateHeartRateLookup() {
        var lookup: [Date: Int] = [:]
        for point in store.state.heartRateSeries {
            let rounded = point.0.toRounded(on: 1, .minute)
            lookup[rounded] = Int(point.1)
        }
        self.heartRatePointInfos = lookup
    }

    /// Search within +/- 2 minutes for nearest heart rate sample
    private func nearestHeartRate(at date: Date) -> Int? {
        for offset in 0...2 {
            if let forward = Calendar.current.date(byAdding: .minute, value: offset, to: date)?.toRounded(on: 1, .minute),
               let hr = heartRatePointInfos[forward] {
                return hr
            }
            if offset > 0,
               let backward = Calendar.current.date(byAdding: .minute, value: -offset, to: date)?.toRounded(on: 1, .minute),
               let hr = heartRatePointInfos[backward] {
                return hr
            }
        }
        return nil
    }

    private func populateValues(glucoseValues: [InsulinDelivery]) -> [InsulinDatapoint] {
        glucoseValues.map { value in
            value.toDatapoint(minDate: startMarker ?? Date(), maxDate: endMarker ?? Date())
        }
        .compactMap { $0 }
    }

    private func populateValues(glucoseValues: [BloodGlucose]) -> [GlucoseDatapoint] {
        glucoseValues.map { value in
            value.toDatapoint(glucoseUnit: store.state.glucoseUnit, alarmLow: store.state.alarmLow, alarmHigh: store.state.alarmHigh)
        }
        .compactMap { $0 }
    }

    private func populateValues(glucoseValues: [SensorGlucose]) -> [GlucoseDatapoint] {
        return glucoseValues.map { value in
            value.toDatapoint(glucoseUnit: store.state.glucoseUnit, alarmLow: store.state.alarmLow, alarmHigh: store.state.alarmHigh)
        }.compactMap { $0 }
    }

    private func populateSmoothValues(glucoseValues: [SensorGlucose]) -> [GlucoseDatapoint] {
        return glucoseValues.map { value in
            if value.timestamp < store.state.smoothThreshold {
                return value.toSmoothDatapoint(glucoseUnit: store.state.glucoseUnit, alarmLow: store.state.alarmLow, alarmHigh: store.state.alarmHigh)
            }

            return value.toDatapoint(glucoseUnit: store.state.glucoseUnit, alarmLow: store.state.alarmLow, alarmHigh: store.state.alarmHigh)
        }.compactMap { $0 }
    }
}

// MARK: - ChartDatapoint + Equatable

extension GlucoseDatapoint: Equatable {
    static func == (lhs: GlucoseDatapoint, rhs: GlucoseDatapoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ZoomLevel

private struct ZoomLevel {
    let level: Int
    let name: String
    let visibleHours: Int
    let labelEvery: Int
}

// MARK: Equatable

extension ZoomLevel: Equatable {
    static func == (lhs: ZoomLevel, rhs: ZoomLevel) -> Bool {
        lhs.level == rhs.level
    }
}

// MARK: - ChartDatapoint

private struct GlucoseDatapoint: Identifiable {
    let id: String
    let time: Date
    let value: Double
    let info: String
    var level: String = "inRange"
}

private struct GlucoseSegment: Identifiable {
    let id: String
    let level: String
    let points: [GlucoseDatapoint]

    var color: Color {
        switch level {
        case "low": return AmberTheme.cgaRed
        case "lowBuffer": return AmberTheme.glucoseLowBuffer
        case "inRange": return AmberTheme.cgaGreen
        case "rising": return AmberTheme.glucoseRising
        case "approaching": return AmberTheme.amber
        case "highBuffer": return AmberTheme.glucoseHighBuffer
        case "high": return AmberTheme.cgaRed
        default: return AmberTheme.cgaGreen
        }
    }
}

/// Splits a glucose series into contiguous segments by level,
/// with one overlapping boundary point so lines connect across transitions.
private func segmentGlucoseSeries(_ series: [GlucoseDatapoint]) -> [GlucoseSegment] {
    guard !series.isEmpty else { return [] }

    var segments: [GlucoseSegment] = []
    var currentLevel = series[0].level
    var currentPoints: [GlucoseDatapoint] = [series[0]]

    for i in 1..<series.count {
        let point = series[i]
        if point.level == currentLevel {
            currentPoints.append(point)
        } else {
            // Include this boundary point in the current segment so the line reaches it
            currentPoints.append(point)
            segments.append(GlucoseSegment(
                id: "seg-\(segments.count)-\(currentLevel)",
                level: currentLevel,
                points: currentPoints
            ))
            // Start new segment from previous point (overlap) so the new line starts connected
            currentPoints = [series[i - 1], point]
            currentLevel = point.level
        }
    }

    if !currentPoints.isEmpty {
        segments.append(GlucoseSegment(
            id: "seg-\(segments.count)-\(currentLevel)",
            level: currentLevel,
            points: currentPoints
        ))
    }

    return segments
}

private struct InsulinDatapoint: Identifiable {
    let id: String
    let starts: Date
    let ends: Date
    let value: Double
    let type: InsulinType
    let info: String
}

private struct MealDatapoint: Identifiable {
    let id: String
    let time: Date
    let label: String
    let carbs: Double?
}

private extension MealEntry {
    func toDatapoint() -> MealDatapoint {
        return MealDatapoint(
            id: id.uuidString,
            time: timestamp,
            label: mealDescription,
            carbs: carbsGrams
        )
    }
}

private struct ExerciseDatapoint: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let activityType: String
}

private extension ExerciseEntry {
    func toDatapoint() -> ExerciseDatapoint {
        return ExerciseDatapoint(
            id: id.uuidString,
            startTime: startTime,
            endTime: endTime,
            activityType: activityType
        )
    }
}

private extension InsulinDelivery {
    func toDatapoint(minDate: Date, maxDate: Date) -> InsulinDatapoint {
        return InsulinDatapoint(
            id: id.uuidString,
            starts: max(minDate, starts),
            ends: min(maxDate, ends),
            value: units,
            type: type,
            info: type.localizedDescription
        )
    }
}

private extension BloodGlucose {
    func toDatapointID(glucoseUnit: GlucoseUnit) -> String {
        "\(id.uuidString)-\(glucoseUnit.rawValue)"
    }

    func toDatapoint(glucoseUnit: GlucoseUnit, alarmLow: Int, alarmHigh: Int) -> GlucoseDatapoint {
        if glucoseUnit == .mmolL {
            return GlucoseDatapoint(
                id: toDatapointID(glucoseUnit: glucoseUnit),
                time: timestamp,
                value: glucoseValue.toMmolL(),
                info: glucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
            )
        }

        return GlucoseDatapoint(
            id: toDatapointID(glucoseUnit: glucoseUnit),
            time: timestamp,
            value: glucoseValue.toDouble(),
            info: glucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        )
    }
}

private extension SensorGlucose {
    func toDatapointID(glucoseUnit: GlucoseUnit) -> String {
        "\(id.uuidString)-\(glucoseUnit.rawValue)"
    }

    func toRawDatapoint(glucoseUnit: GlucoseUnit, alarmLow: Int, alarmHigh: Int, shiftY: Int = 0) -> GlucoseDatapoint {
        if glucoseUnit == .mmolL {
            return GlucoseDatapoint(
                id: toDatapointID(glucoseUnit: glucoseUnit),
                time: timestamp,
                value: rawGlucoseValue.toMmolL() + shiftY.toMmolL(),
                info: rawGlucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
            )
        }

        return GlucoseDatapoint(
            id: toDatapointID(glucoseUnit: glucoseUnit),
            time: timestamp,
            value: rawGlucoseValue.toDouble() + shiftY.toDouble(),
            info: rawGlucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        )
    }

    func toSmoothDatapoint(glucoseUnit: GlucoseUnit, alarmLow: Int, alarmHigh: Int, shiftY: Int = 0) -> GlucoseDatapoint {
        let glucose = (smoothGlucoseValue ?? Double(glucoseValue))
        let info = glucose.toInteger()?.asGlucose(glucoseUnit: glucoseUnit, withUnit: true) ?? ""
        let level = AmberTheme.glucoseLevel(forValue: Int(glucose), low: alarmLow, high: alarmHigh)

        if glucoseUnit == .mmolL {
            return GlucoseDatapoint(
                id: toDatapointID(glucoseUnit: glucoseUnit),
                time: timestamp,
                value: glucose.toMmolL() + shiftY.toMmolL(),
                info: info,
                level: level
            )
        }

        return GlucoseDatapoint(
            id: toDatapointID(glucoseUnit: glucoseUnit),
            time: timestamp,
            value: glucose + shiftY.toDouble(),
            info: info,
            level: level
        )
    }

    func toDatapoint(glucoseUnit: GlucoseUnit, alarmLow: Int, alarmHigh: Int, shiftY: Int = 0) -> GlucoseDatapoint {
        var info: String

        if let minuteChange = minuteChange {
            info = "\(glucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)) \(minuteChange.asMinuteChange(glucoseUnit: glucoseUnit))"
        } else {
            info = glucoseValue.asGlucose(glucoseUnit: glucoseUnit, withUnit: true)
        }

        let level = AmberTheme.glucoseLevel(forValue: glucoseValue, low: alarmLow, high: alarmHigh)

        if glucoseUnit == .mmolL {
            return GlucoseDatapoint(
                id: toDatapointID(glucoseUnit: glucoseUnit),
                time: timestamp,
                value: glucoseValue.toMmolL() + shiftY.toMmolL(),
                info: info,
                level: level
            )
        }

        return GlucoseDatapoint(
            id: toDatapointID(glucoseUnit: glucoseUnit),
            time: timestamp,
            value: glucoseValue.toDouble() + shiftY.toDouble(),
            info: info,
            level: level
        )
    }
}

