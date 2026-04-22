//
//  GlucoseChartView.swift
//  DOSBTS
//

import Charts
import SwiftUI

// MARK: - ChartView

// MARK: - ReportType

private enum ReportType: String, CaseIterable {
    case glucose = "GLUCOSE"
    case timeInRange = "TIME IN RANGE"
    case statistics = "STATISTICS"
}

struct ChartView: View {
    // MARK: Internal

    @EnvironmentObject var store: DirectStore
    @State private var selectedReportType: ReportType = .glucose

    var body: some View {
        Section(
            content: {
                VStack {
                    ReportTypeSelectorView

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
        )
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

                    HStack {
                        Text(store.state.glucoseUnit.localizedDescription)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(AmberTheme.amberMuted)
                        Spacer()
                        if !store.state.heartRateSeries.isEmpty {
                            HStack(spacing: 3) {
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(AmberTheme.cgaMagenta.opacity(0.4))
                                    .frame(width: 12, height: 2)
                                Text("HR")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundColor(AmberTheme.cgaMagenta.opacity(0.5))
                            }
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        ScrollViewReader { scrollViewProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    EventMarkerLaneView(
                                        markerGroups: markerGroups,
                                        totalWidth: max(0, screenWidth, seriesWidth),
                                        timeRange: (startMarker ?? Date())...(endMarker ?? Date()),
                                        scoredMealEntryIds: store.state.scoredMealEntryIds,
                                        onTapMeal: { mealID in
                                            if let meal = store.state.mealEntryValues.first(where: { $0.id == mealID }) {
                                                if activeMealOverlay?.id == meal.id {
                                                    activeMealOverlay = nil
                                                } else {
                                                    activeMealOverlay = meal
                                                }
                                            }
                                        },
                                        onTapInsulin: { insulinID in
                                            if let insulin = store.state.insulinDeliveryValues.first(where: { $0.id == insulinID }) {
                                                tappedInsulinEntry = insulin
                                                showInsulinDetail = true
                                            }
                                        },
                                        expandedGroupID: $expandedGroupID
                                    )
                                    .frame(width: max(0, screenWidth, seriesWidth), height: Config.markerLaneHeight)

                                    ChartView
                                        .frame(width: max(0, screenWidth, seriesWidth), height: min(screenHeight, Config.chartHeight))
                                    .onChange(of: store.state.sensorGlucoseValues) { _ in
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.bloodGlucoseValues) { _ in
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.insulinDeliveryValues) { _ in
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onChange(of: store.state.chartZoomLevel) { _ in
                                        scrollToEnd(scrollViewProxy: scrollViewProxy, force: true)

                                    }.onAppear {
                                        scrollToEnd(scrollViewProxy: scrollViewProxy)

                                    }.onTapGesture(count: 2) {
                                        showUnsmoothedValues = !showUnsmoothedValues
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

                                if let hr = selectedHeartRate {
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

                    ZoomLevelsView
        }
        .sheet(item: $tappedMealEntry) { meal in
            AddMealView(
                timestamp: meal.timestamp,
                mealDescription: meal.mealDescription,
                carbsGrams: meal.carbsGrams
            ) { newTimestamp, newDescription, newCarbs in
                store.dispatch(.deleteMealEntry(mealEntry: meal))
                let updated = MealEntry(
                    timestamp: newTimestamp,
                    mealDescription: newDescription,
                    carbsGrams: newCarbs
                )
                store.dispatch(.addMealEntry(mealEntryValues: [updated]))
            } deleteCallback: {
                store.dispatch(.deleteMealEntry(mealEntry: meal))
            }
        }
        .confirmationDialog(
            insulinDetailTitle,
            isPresented: $showInsulinDetail,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let insulin = tappedInsulinEntry {
                    store.dispatch(.deleteInsulinDelivery(insulinDelivery: insulin))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $tappedMealGroup) { group in
            NavigationView {
                List {
                    Section {
                        HStack {
                            Text("Total")
                                .font(DOSTypography.body)
                                .foregroundColor(AmberTheme.amber)
                            Spacer()
                            if let carbs = group.totalCarbs {
                                Text("\(Int(carbs))g carbs")
                                    .font(DOSTypography.body)
                                    .foregroundColor(AmberTheme.cgaGreen)
                            }
                            if let cals = group.totalCalories {
                                Text("\(Int(cals)) cal")
                                    .font(DOSTypography.caption)
                                    .foregroundColor(AmberTheme.amberDark)
                            }
                        }
                    }

                    Section(header: Text("\(group.count) items")) {
                        ForEach(group.entries) { entry in
                            Button {
                                tappedMealGroup = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    tappedMealEntry = entry
                                }
                            } label: {
                                HStack {
                                    Text(entry.mealDescription)
                                        .font(DOSTypography.bodySmall)
                                        .foregroundColor(AmberTheme.amberLight)
                                    Spacer()
                                    if let carbs = entry.carbsGrams {
                                        Text("\(Int(carbs))g")
                                            .font(DOSTypography.caption)
                                            .foregroundColor(AmberTheme.cgaGreen)
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    store.dispatch(.deleteMealEntry(mealEntry: entry))
                                }
                            }
                        }
                    }
                }
                .listStyle(.grouped)
                .navigationTitle("\(group.count) Meals")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { tappedMealGroup = nil }
                            .font(DOSTypography.caption)
                    }
                }
            }
        }
        .sheet(item: $tappedInsulinGroup) { group in
            NavigationView {
                List {
                    Section {
                        HStack {
                            Text("Total")
                                .font(DOSTypography.body)
                                .foregroundColor(AmberTheme.amber)
                            Spacer()
                            Text(group.totalUnits.asInsulin())
                                .font(DOSTypography.body)
                                .foregroundColor(AmberTheme.amberDark)
                        }
                    }

                    Section(header: Text("\(group.count) doses")) {
                        ForEach(group.entries) { entry in
                            HStack {
                                Text(entry.type.localizedDescription)
                                    .font(DOSTypography.bodySmall)
                                    .foregroundColor(AmberTheme.amberLight)
                                Spacer()
                                Text(entry.units.asInsulin())
                                    .font(DOSTypography.caption)
                                    .foregroundColor(AmberTheme.amberDark)
                                Text(entry.starts.toLocalTime())
                                    .font(DOSTypography.caption)
                                    .foregroundColor(AmberTheme.amberDark)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    store.dispatch(.deleteInsulinDelivery(insulinDelivery: entry))
                                }
                            }
                        }
                    }
                }
                .listStyle(.grouped)
                .navigationTitle("\(group.count) Insulin Doses")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { tappedInsulinGroup = nil }
                            .font(DOSTypography.caption)
                    }
                }
            }
        }
    }

    // MARK: - Report Type Selector

    private var ReportTypeSelectorView: some View {
        HStack(spacing: DOSSpacing.sm) {
            ForEach(ReportType.allCases, id: \.self) { type in
                Button(action: {
                    DirectNotifications.shared.hapticFeedback()
                    selectedReportType = type
                }) {
                    HStack(spacing: 4) {
                        Circle()
                            .if(selectedReportType == type) {
                                $0.fill(AmberTheme.amberLight)
                            } else: {
                                $0.stroke(AmberTheme.amberLight)
                            }
                            .frame(width: 8, height: 8)

                        Text(type.rawValue)
                            .font(DOSTypography.caption)
                            .foregroundColor(selectedReportType == type ? AmberTheme.amberLight : AmberTheme.amberDark)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
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

    var ZoomLevelsView: some View {
        HStack {
            ForEach(Config.zoomLevels, id: \.level) { zoom in
                if zoom != Config.zoomLevels.first {
                    Spacer()
                }

                Button(
                    action: {
                        DirectNotifications.shared.hapticFeedback()
                        store.dispatch(.setChartZoomLevel(level: zoom.level))
                    },
                    label: {
                        Circle()
                            .if(isSelectedZoomLevel(level: zoom.level)) {
                                $0.fill(AmberTheme.amberLight)
                            } else: {
                                $0.stroke(AmberTheme.amberLight)
                            }
                            .frame(width: 12, height: 12)

                        Text(zoom.name)
                            .font(DOSTypography.bodySmall)
                            .foregroundColor(AmberTheme.amberLight)
                    }
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
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
                    ForEach(Array(iobSeries.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("IOB", point.mealSnack.map(from: 0...iobCeiling, to: 0...Double(alarmLow)))
                        )
                        .foregroundStyle(AmberTheme.cgaCyan.opacity(0.3))
                        .interpolationMethod(.monotone)
                    }

                    ForEach(Array(iobSeries.enumerated()), id: \.offset) { _, point in
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("IOB-corr", point.corrBasal.map(from: 0...iobCeiling, to: 0...Double(alarmLow)))
                        )
                        .foregroundStyle(AmberTheme.amberDark.opacity(0.3))
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

            // MARK: - Meal Impact Overlay
            if let overlayMeal = activeMealOverlay {
                let windowEnd = overlayMeal.timestamp.addingTimeInterval(2 * 60 * 60)
                let isInProgress = Date() < windowEnd
                let displayEnd = isInProgress ? Date() : windowEnd

                // Shaded 2hr band
                RectangleMark(
                    xStart: .value("MealStart", overlayMeal.timestamp),
                    xEnd: .value("MealEnd", displayEnd),
                    yStart: .value("Bottom", 0),
                    yEnd: .value("Top", chartMinimum)
                )
                .foregroundStyle(AmberTheme.cgaGreen.opacity(0.08))

                // Delta annotation at the center of the band
                let midTime = overlayMeal.timestamp.addingTimeInterval(displayEnd.timeIntervalSince(overlayMeal.timestamp) / 2)
                let overlayDelta = computeMealOverlayDelta(meal: overlayMeal, isInProgress: isInProgress)

                PointMark(
                    x: .value("Time", midTime),
                    y: .value("Label", chartMinimum * 0.85)
                )
                .symbolSize(0)
                .annotation(position: .overlay) {
                    VStack(spacing: 2) {
                        let confounders = detectMealConfounders(meal: overlayMeal)
                        let deltaOpacity = (overlayDelta.isLowConfidence ? 0.5 : 1.0) * (confounders.isClean ? 1.0 : 0.5)

                        if isInProgress {
                            Text("IN PROGRESS")
                                .font(DOSTypography.caption)
                                .foregroundStyle(AmberTheme.amberDark)
                        }

                        if let delta = overlayDelta.delta {
                            let displayDelta: String = {
                                let prefix = overlayDelta.isLowConfidence ? "~" : ""
                                if store.state.glucoseUnit == .mgdL {
                                    return prefix + (delta >= 0 ? "+" : "") + "\(delta)"
                                } else {
                                    let mmolDelta = Double(delta) / 18.0182
                                    return prefix + (delta >= 0 ? "+" : "") + String(format: "%.1f", mmolDelta)
                                }
                            }()
                            Text(displayDelta)
                                .font(DOSTypography.body)
                                .bold()
                                .foregroundStyle(deltaColor(delta))
                                .opacity(deltaOpacity)

                            Text(store.state.glucoseUnit == .mgdL ? "mg/dL" : "mmol/L")
                                .font(DOSTypography.caption)
                                .foregroundStyle(AmberTheme.amberDark)
                        } else {
                            Text("--")
                                .font(DOSTypography.body)
                                .foregroundStyle(AmberTheme.amberDark)
                        }

                        // Confounder indicators
                        if !confounders.isClean {
                            HStack(spacing: 4) {
                                if confounders.hasCorrectionBolus {
                                    Image(systemName: "syringe.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AmberTheme.amberDark)
                                }
                                if confounders.hasExercise {
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AmberTheme.amberDark)
                                }
                                if confounders.hasStackedMeal {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AmberTheme.amberDark)
                                }
                            }
                        }

                        // PersonalFood glycemic average
                        if let sessionId = overlayMeal.analysisSessionId,
                           let food = store.state.personalFoodValues.first(where: { $0.analysisSessionId == sessionId }),
                           food.observationCount >= 2,
                           let avg = food.avgDeltaMgDL {
                            let avgDisplay: String = {
                                if store.state.glucoseUnit == .mgdL {
                                    return "avg +\(Int(avg))"
                                } else {
                                    return "avg +\(String(format: "%.1f", avg / 18.0182))"
                                }
                            }()
                            Text("\(avgDisplay) (\(food.observationCount))")
                                .font(DOSTypography.caption)
                                .foregroundStyle(AmberTheme.amberDark)
                        }

                        // Edit button
                        Button(action: {
                            tappedMealEntry = activeMealOverlay
                            activeMealOverlay = nil
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                                .foregroundStyle(AmberTheme.amber)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(4)
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

            ForEach(store.state.heartRateSeries.indices, id: \.self) { index in
                let point = store.state.heartRateSeries[index]
                let normalizedHR = ((point.1 - 40) / (200 - 40)) * (chartMinimum - alarmHigh) + alarmHigh
                LineMark(
                    x: .value("Time", point.0),
                    y: .value("HR", normalizedHR),
                    series: .value("Series", "HeartRate")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(AmberTheme.cgaMagenta.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
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
        .onChange(of: store.state.showSmoothedGlucose) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: sensorGlucoseValues")

                debounceSeriesMetadata()
                updateSensorSeries()
            }

        }.onChange(of: store.state.sensorGlucoseValues) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: sensorGlucoseValues")

                debounceSeriesMetadata()
                updateSensorSeries()
                updateSmoothedMinuteChange()
            }

        }.onChange(of: store.state.bloodGlucoseValues) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: bloodGlucoseValues")

                debounceSeriesMetadata()
                updateBloodSeries()
            }

        }.onChange(of: store.state.insulinDeliveryValues) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: insulinDeliveryValues")

                debounceSeriesMetadata()
                updateInsulinSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.iobDeliveries.count) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: iobDeliveries")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.bolusInsulinPreset) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: bolusInsulinPreset")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.basalDIAMinutes) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: basalDIAMinutes")
                updateInsulinSeries()
            }

        }.onChange(of: store.state.mealEntryValues) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: mealEntryValues")

                debounceSeriesMetadata()
                updateMealSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.exerciseEntryValues) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: exerciseEntryValues")

                debounceSeriesMetadata()
                updateExerciseSeries()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.chartZoomLevel) { _ in
            if shouldRefresh {
                DirectLog.info("onChange: chartZoomLevel")

                debounceSeriesMetadata()
                updateMarkerGroups()
            }

        }.onChange(of: store.state.showSmoothedGlucose) { _ in
            showUnsmoothedValues = false

        }.onChange(of: store.state.selectedDate) { _ in
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

                                // Search nearby minutes for heart rate (HR samples may not align exactly)
                                self.selectedHeartRate = nearestHeartRate(at: rounded)
                            }
                        }
                        .onEnded { dragValue in
                            let wasTap = abs(dragValue.translation.width) < 10 && abs(dragValue.translation.height) < 10

                            selectedSmoothSensorPoint = nil
                            selectedRawSensorPoint = nil
                            selectedBloodPoint = nil
                            selectedHeartRate = nil

                            guard wasTap else { return }

                            // Dismiss meal overlay and expanded marker group on any chart tap
                            activeMealOverlay = nil
                            expandedGroupID = nil
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
        static let markerLaneHeight: CGFloat = 32
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
    @State private var mealGroups: [MealGroup] = []
    @State private var insulinGroups: [InsulinGroup] = []
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

    @State private var tappedMealEntry: MealEntry? = nil
    @State private var tappedInsulinEntry: InsulinDelivery? = nil
    @State private var showInsulinDetail = false
    @State private var tappedMealGroup: MealGroup? = nil
    @State private var tappedInsulinGroup: InsulinGroup? = nil
    @State private var activeMealOverlay: MealEntry? = nil

    @State private var markerGroups: [ConsolidatedMarkerGroup] = []
    @State private var expandedGroupID: String? = nil

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

    private var startMarker: Date? {
        return firstTimestamp
    }

    private var endMarker: Date? {
        if let lastTimestamp = lastTimestamp, store.state.selectedDate == nil {
            if let zoomLevel = zoomLevel, zoomLevel.level == 1 {
                return Calendar.current.date(byAdding: .minute, value: 15, to: lastTimestamp)!
            }

            return Calendar.current.date(byAdding: .hour, value: 1, to: lastTimestamp)!
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

    private func isSelectedZoomLevel(level: Int) -> Bool {
        if let zoomLevel = zoomLevel, zoomLevel.level == level {
            return true
        }

        return false
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

                // Group non-basal insulin by timegroup for chart display
                let bolusEntries = store.state.insulinDeliveryValues.filter { $0.type != .basal }
                let grouped = Dictionary(grouping: bolusEntries, by: \.timegroup)
                self.insulinGroups = grouped.map { timegroup, entries in
                    InsulinGroup(id: timegroup, entries: entries, time: timegroup)
                }.sorted { $0.time < $1.time }
            }
        }
    }

    private func updateMealSeries() {
        DirectLog.info("updateMealSeries()")
        self.mealSeries = store.state.mealEntryValues.map { $0.toDatapoint() }

        // Group meals by timegroup (15-min window) for chart display
        let grouped = Dictionary(grouping: store.state.mealEntryValues, by: \.timegroup)
        self.mealGroups = grouped.map { timegroup, entries in
            MealGroup(id: timegroup, entries: entries, time: timegroup)
        }.sorted { $0.time < $1.time }
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

    private var mealDetailTitle: String {
        guard let meal = tappedMealEntry else { return "" }
        var title = "\(meal.timestamp.toLocalDateTime())\n\(meal.mealDescription)"
        if let c = meal.carbsGrams { title += "\n\(Int(c))g carbs" }
        if let p = meal.proteinGrams { title += " · \(Int(p))g P" }
        if let f = meal.fatGrams { title += " · \(Int(f))g F" }
        if let cal = meal.calories { title += " · \(Int(cal)) kcal" }
        return title
    }

    private var insulinDetailTitle: String {
        guard let insulin = tappedInsulinEntry else { return "" }
        return "\(insulin.starts.toLocalDateTime())\n\(insulin.type.localizedDescription)\n\(insulin.units.asInsulin())"
    }

    /// Search within +/- 2 minutes for nearest heart rate sample
    private func nearestHeartRate(at date: Date) -> Int? {
        for offset in 0...2 {
            let forward = Calendar.current.date(byAdding: .minute, value: offset, to: date)!.toRounded(on: 1, .minute)
            if let hr = heartRatePointInfos[forward] { return hr }
            if offset > 0 {
                let backward = Calendar.current.date(byAdding: .minute, value: -offset, to: date)!.toRounded(on: 1, .minute)
                if let hr = heartRatePointInfos[backward] { return hr }
            }
        }
        return nil
    }

    private struct MealOverlayDelta {
        let delta: Int?
        let isLowConfidence: Bool
    }

    private func computeMealOverlayDelta(meal: MealEntry, isInProgress: Bool) -> MealOverlayDelta {
        let windowEnd = isInProgress ? Date() : meal.timestamp.addingTimeInterval(2 * 60 * 60)

        // Filter glucose readings in the window
        let readings = store.state.sensorGlucoseValues.filter { glucose in
            glucose.timestamp >= meal.timestamp && glucose.timestamp <= windowEnd
        }

        guard !readings.isEmpty else {
            return MealOverlayDelta(delta: nil, isLowConfidence: false)
        }

        // Baseline: closest reading before meal within 15 min
        let baselineStart = meal.timestamp.addingTimeInterval(-15 * 60)
        let baseline = store.state.sensorGlucoseValues
            .filter { $0.timestamp >= baselineStart && $0.timestamp < meal.timestamp }
            .last // already sorted by time

        let referenceGlucose: Int
        if let baseline = baseline {
            referenceGlucose = baseline.glucoseValue
        } else if let first = readings.first {
            referenceGlucose = first.glucoseValue
        } else {
            return MealOverlayDelta(delta: nil, isLowConfidence: false)
        }

        // Peak
        guard let peak = readings.max(by: { $0.glucoseValue < $1.glucoseValue }) else {
            return MealOverlayDelta(delta: nil, isLowConfidence: false)
        }
        let delta = peak.glucoseValue - referenceGlucose

        // Low confidence: fewer than 4 readings regardless of in-progress state
        let isLowConfidence = readings.count < 4

        return MealOverlayDelta(delta: delta, isLowConfidence: isLowConfidence)
    }

    private struct MealConfounders {
        let hasCorrectionBolus: Bool
        let hasExercise: Bool
        let hasStackedMeal: Bool

        var isClean: Bool { !hasCorrectionBolus && !hasExercise && !hasStackedMeal }
    }

    private func detectMealConfounders(meal: MealEntry) -> MealConfounders {
        let windowEnd = meal.timestamp.addingTimeInterval(2 * 60 * 60)

        let hasCorrectionBolus = store.state.insulinDeliveryValues.contains { delivery in
            delivery.starts >= meal.timestamp && delivery.starts <= windowEnd && delivery.type == .correctionBolus
        }

        let hasExercise = store.state.exerciseEntryValues.contains { exercise in
            exercise.startTime <= windowEnd && exercise.endTime >= meal.timestamp
        }

        let hasStackedMeal = store.state.mealEntryValues.contains { other in
            other.id != meal.id && other.timestamp >= meal.timestamp && other.timestamp <= windowEnd
        }

        return MealConfounders(hasCorrectionBolus: hasCorrectionBolus, hasExercise: hasExercise, hasStackedMeal: hasStackedMeal)
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta < 30 {
            return AmberTheme.cgaGreen
        } else if delta < 60 {
            return AmberTheme.amber
        } else {
            return AmberTheme.cgaRed
        }
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

private struct MealGroup: Identifiable {
    let id: Date // the timegroup
    let entries: [MealEntry]
    let time: Date

    var totalCarbs: Double? {
        let values = entries.compactMap(\.carbsGrams)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var totalCalories: Double? {
        let values = entries.compactMap(\.calories)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var count: Int { entries.count }
}

private struct InsulinGroup: Identifiable {
    let id: Date // the timegroup
    let entries: [InsulinDelivery]
    let time: Date
    var totalUnits: Double { entries.reduce(0) { $0 + $1.units } }
    var count: Int { entries.count }
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

// MARK: - Marker Lane Types

enum MarkerType: Hashable {
    case meal
    case bolus
    case exercise

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .bolus: return "syringe.fill"
        case .exercise: return "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .meal: return AmberTheme.cgaGreen
        case .bolus: return AmberTheme.amberDark
        case .exercise: return AmberTheme.cgaCyan
        }
    }
}

struct EventMarker: Identifiable {
    let id: String
    let time: Date
    let type: MarkerType
    let label: String
    let rawValue: Double
    let sourceID: UUID
}

struct ConsolidatedMarkerGroup: Identifiable {
    let id: String
    let time: Date
    let markers: [EventMarker]

    var isSingle: Bool { markers.count == 1 }

    var dominantType: MarkerType {
        let counts = Dictionary(grouping: markers, by: \.type).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .meal
    }

    var summaryLabel: String {
        let totalCarbs = markers
            .filter { $0.type == .meal }
            .reduce(0.0) { $0 + $1.rawValue }
        if totalCarbs > 0 {
            return "\(Int(totalCarbs))g"
        }
        return "\(markers.count)"
    }

    var totalCarbs: Double? {
        let carbs = markers.filter { $0.type == .meal }.reduce(0.0) { $0 + $1.rawValue }
        return carbs > 0 ? carbs : nil
    }
}
