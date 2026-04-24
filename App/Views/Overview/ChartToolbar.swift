//
//  ChartToolbar.swift
//  DOSBTS
//

import SwiftUI

// MARK: - ReportType

enum ReportType: String, CaseIterable {
    case glucose = "GLUCOSE"
    case timeInRange = "TIME IN RANGE"
    case statistics = "STATISTICS"
}

// MARK: - ChartToolbarView

struct ChartToolbarView: View {
    @EnvironmentObject var store: DirectStore
    @Binding var selectedReportType: ReportType

    var body: some View {
        VStack(spacing: DOSSpacing.xs) {
            reportTypeRow
            zoomRow
        }
        .padding(.vertical, DOSSpacing.xs)
        .background(AmberTheme.dosBlack)
        .onAppear(perform: normaliseDaysIfNeeded)
        .onChange(of: selectedReportType) { _ in normaliseDaysIfNeeded() }
    }

    /// When the user switches to TIR or STATISTICS and the persisted `statisticsDays`
    /// is not one of the day chips exposed here (e.g. user previously picked `3d`
    /// in the Lists → Statistics picker), bump it to `30d` so a chip always
    /// reflects the active aggregation window.
    private func normaliseDaysIfNeeded() {
        guard selectedReportType != .glucose else { return }
        let validDays: Set<Int> = Set(DaysZoom.allCases.map(\.days))
        guard !validDays.contains(store.state.statisticsDays) else { return }
        store.dispatch(.setStatisticsDays(days: 30))
    }

    private var reportTypeRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(ReportType.allCases, id: \.self) { type in
                Button {
                    selectedReportType = type
                } label: {
                    Text(type.rawValue)
                        .font(selectedReportType == type ? DOSTypography.bodySmall.weight(.bold) : DOSTypography.bodySmall)
                        .foregroundColor(selectedReportType == type ? AmberTheme.amber : AmberTheme.amberDark)
                        .padding(.vertical, DOSSpacing.md)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AmberTheme.amber)
                                .frame(height: 2)
                                .opacity(selectedReportType == type ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(type.rawValue)
                .accessibilityAddTraits(selectedReportType == type ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    @ViewBuilder
    private var zoomRow: some View {
        switch selectedReportType {
        case .glucose:
            hoursZoomRow
        case .timeInRange, .statistics:
            daysZoomRow
        }
    }

    private var hoursZoomRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(HoursZoom.allCases, id: \.self) { zoom in
                Button {
                    store.dispatch(.setChartZoomLevel(level: zoom.level))
                } label: {
                    zoomLabel(text: zoom.label, selected: isSelectedHours(zoom))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(zoom.label)
                .accessibilityAddTraits(isSelectedHours(zoom) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private var daysZoomRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(DaysZoom.allCases, id: \.self) { zoom in
                Button {
                    store.dispatch(.setStatisticsDays(days: zoom.days))
                } label: {
                    zoomLabel(text: zoom.label, selected: isSelectedDays(zoom))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(zoom.label)
                .accessibilityAddTraits(isSelectedDays(zoom) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func zoomLabel(text: String, selected: Bool) -> some View {
        Text(text)
            .font(selected ? DOSTypography.caption.weight(.bold) : DOSTypography.caption)
            .foregroundColor(selected ? AmberTheme.amber : AmberTheme.amberDark)
            .padding(.vertical, DOSSpacing.sm)
            .padding(.horizontal, DOSSpacing.xs)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AmberTheme.amber)
                    .frame(height: 2)
                    .opacity(selected ? 1 : 0)
            }
    }

    private func isSelectedHours(_ zoom: HoursZoom) -> Bool {
        store.state.chartZoomLevel == zoom.level
    }

    private func isSelectedDays(_ zoom: DaysZoom) -> Bool {
        store.state.statisticsDays == zoom.days
    }
}

// MARK: - HoursZoom

private enum HoursZoom: CaseIterable {
    case three, six, twelve, twentyFour

    var level: Int {
        switch self {
        case .three: return 3
        case .six: return 6
        case .twelve: return 12
        case .twentyFour: return 24
        }
    }

    var label: String { "\(level)h" }
}

// MARK: - DaysZoom

private enum DaysZoom: CaseIterable {
    case seven, thirty, ninety, all

    /// Sentinel for "All" — large enough that the stats SQL window covers every available reading.
    /// `getSensorGlucoseStatistics` clamps naturally via `MIN/MAX(timestamp)` against the actual table range.
    static let allDays = 9999

    var days: Int {
        switch self {
        case .seven: return 7
        case .thirty: return 30
        case .ninety: return 90
        case .all: return DaysZoom.allDays
        }
    }

    var label: String {
        switch self {
        case .seven: return "7d"
        case .thirty: return "30d"
        case .ninety: return "90d"
        case .all: return "ALL"
        }
    }
}

// MARK: - Preview

struct ChartToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ChartToolbarView(selectedReportType: .constant(.timeInRange))
                .environmentObject(DirectStore(initialState: AppState(), reducer: directReducer, middlewares: []))
            Spacer()
        }
        .background(AmberTheme.dosBlack)
        .preferredColorScheme(.dark)
    }
}
