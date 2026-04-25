//
//  DigestView.swift
//  DOSBTSApp
//

import SwiftUI

// MARK: - DigestView

struct DigestView: View {
    @EnvironmentObject var store: DirectStore

    @State private var selectedDate: Date = Date()
    @State private var hasAppeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: DOSSpacing.md) {
                dateNavigationBar

                if store.state.dailyDigestLoading {
                    loadingView
                } else if let digest = store.state.currentDailyDigest {
                    statsGrid(digest: digest)
                    aiInsightCard(digest: digest)
                    eventTimeline
                } else {
                    noDataView
                }
            }
            .padding(.horizontal, DOSSpacing.md)
            .padding(.top, DOSSpacing.sm)
        }
        .background(Color.black)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                store.dispatch(.loadDailyDigest(date: selectedDate))
            }
        }
    }

    // MARK: - Date Navigation

    private var dateNavigationBar: some View {
        HStack {
            Button(action: { navigateDate(by: -1) }) {
                Text("<")
                    .font(DOSTypography.bodyLarge)
                    .foregroundColor(AmberTheme.amberDark)
            }

            Spacer()

            Text(dateLabel)
                .font(DOSTypography.bodyLarge)
                .foregroundColor(AmberTheme.amber)

            Spacer()

            Button(action: { navigateDate(by: 1) }) {
                Text(">")
                    .font(DOSTypography.bodyLarge)
                    .foregroundColor(isToday ? AmberTheme.amberDark.opacity(0.3) : AmberTheme.amberDark)
            }
            .disabled(isToday)
        }
        .padding(.vertical, DOSSpacing.sm)
    }

    // MARK: - Stats Grid

    private func statsGrid(digest: DailyDigest) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: DOSSpacing.sm),
            GridItem(.flexible(), spacing: DOSSpacing.sm),
            GridItem(.flexible(), spacing: DOSSpacing.sm),
        ], spacing: DOSSpacing.sm) {
            StatCard(
                label: "TIR",
                value: "\(Int(digest.tir))%",
                valueColor: tirColor(digest.tir),
                help: tirHelp(digest.tir)
            )
            StatCard(
                label: "LOWS",
                value: "\(digest.lowCount)",
                valueColor: digest.lowCount > 0 ? AmberTheme.cgaRed : AmberTheme.cgaGreen
            )
            StatCard(
                label: "HIGHS",
                value: "\(digest.highCount)",
                valueColor: digest.highCount > 0 ? AmberTheme.amber : AmberTheme.cgaGreen
            )
            StatCard(
                label: "AVG",
                value: "\(Int(digest.avg))",
                valueColor: AmberTheme.amber,
                help: store.state.glucoseUnit.localizedDescription
            )
            StatCard(
                label: "CARBS",
                value: "\(Int(digest.totalCarbsGrams))g",
                valueColor: AmberTheme.amber
            )
            StatCard(
                label: "INSULIN",
                value: String(format: "%.1fU", digest.totalInsulinUnits),
                valueColor: AmberTheme.amber
            )
        }
    }

    // MARK: - AI Insight Card

    private func aiInsightCard(digest: DailyDigest) -> some View {
        VStack(alignment: .leading, spacing: DOSSpacing.sm) {
            HStack {
                Text("AI INSIGHT")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.cgaCyan)
                Spacer()
                if digest.aiInsight != nil {
                    Button(action: {
                        store.dispatch(.generateDailyDigestInsight(date: selectedDate, force: true))
                    }) {
                        Text("REFRESH")
                            .font(DOSTypography.caption)
                            .foregroundColor(AmberTheme.amberDark)
                    }
                }
            }

            if store.state.dailyDigestInsightLoading {
                Text("ANALYZING...")
                    .font(DOSTypography.body)
                    .foregroundColor(AmberTheme.amberDark)
                    .opacity(0.7)
            } else if let insight = digest.aiInsight, !insight.isEmpty {
                Text(insight)
                    .font(DOSTypography.body)
                    .foregroundColor(AmberTheme.amberLight)
            } else if !store.state.aiConsentDailyDigest {
                Text("ENABLE AI INSIGHTS IN SETTINGS")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
            } else if KeychainService.read(key: ClaudeService.keychainKey) == nil {
                Text("ADD API KEY IN SETTINGS")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
            } else {
                Button(action: {
                    store.dispatch(.generateDailyDigestInsight(date: selectedDate, force: true))
                }) {
                    Text("INSIGHT UNAVAILABLE — TAP TO RETRY")
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amberDark)
                }
            }
        }
        .padding(DOSSpacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(AmberTheme.cgaCyan, lineWidth: 1)
        )
    }

    // MARK: - Event Timeline

    private var eventTimeline: some View {
        VStack(alignment: .leading, spacing: DOSSpacing.xs) {
            Text("TIMELINE")
                .font(DOSTypography.caption)
                .foregroundColor(AmberTheme.amberDark)
                .padding(.bottom, 4)

            if let events = store.state.dailyDigestEvents {
                let timelineItems = buildTimelineItems(events: events)
                if timelineItems.isEmpty {
                    Text("NO EVENTS LOGGED")
                        .font(DOSTypography.caption)
                        .foregroundColor(AmberTheme.amberDark)
                } else {
                    ForEach(timelineItems, id: \.id) { item in
                        HStack(spacing: DOSSpacing.sm) {
                            Text(item.timeString)
                                .font(DOSTypography.caption)
                                .foregroundColor(AmberTheme.amberDark)
                                .frame(width: 45, alignment: .leading)
                            Text(item.label)
                                .font(DOSTypography.caption)
                                .foregroundColor(item.color)
                        }
                    }
                }
            } else {
                Text("LOADING...")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading / No Data States

    private var loadingView: some View {
        VStack {
            Spacer()
            Text("LOADING...")
                .font(DOSTypography.bodyLarge)
                .foregroundColor(AmberTheme.amberDark)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    private var noDataView: some View {
        VStack {
            Spacer()
            Text("NO DATA FOR THIS DAY")
                .font(DOSTypography.bodyLarge)
                .foregroundColor(AmberTheme.amberDark)
            Spacer()
        }
        .frame(minHeight: 200)
    }

    // MARK: - Helpers

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        return formatter.string(from: selectedDate).uppercased()
    }

    private func navigateDate(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        guard newDate <= Date() else { return }
        selectedDate = newDate
        store.dispatch(.loadDailyDigest(date: newDate))
    }

}

// MARK: - Timeline Item

private struct TimelineItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let timeString: String
    let label: String
    let color: Color
}

private func buildTimelineItems(events: DailyDigestEvents) -> [TimelineItem] {
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"

    var items: [TimelineItem] = []

    for meal in events.meals {
        let carbs = meal.carbsGrams.map { "\(Int($0))g" } ?? "?"
        items.append(TimelineItem(
            timestamp: meal.timestamp,
            timeString: timeFormatter.string(from: meal.timestamp),
            label: "\(meal.mealDescription) \(carbs)",
            color: AmberTheme.amber
        ))
    }

    for ins in events.insulin {
        items.append(TimelineItem(
            timestamp: ins.starts,
            timeString: timeFormatter.string(from: ins.starts),
            label: "\(String(format: "%.1f", ins.units))U \(ins.type.description)",
            color: AmberTheme.cgaCyan
        ))
    }

    for ex in events.exercise {
        items.append(TimelineItem(
            timestamp: ex.startTime,
            timeString: timeFormatter.string(from: ex.startTime),
            label: "\(ex.activityType) \(Int(ex.durationMinutes))min",
            color: AmberTheme.cgaGreen
        ))
    }

    return items.sorted { $0.timestamp < $1.timestamp }
}
