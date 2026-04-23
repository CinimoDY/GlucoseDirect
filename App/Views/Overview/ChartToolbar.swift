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

    private var zoomRow: some View {
        HStack(spacing: DOSSpacing.md) {
            ForEach(ZoomLevel.allCases, id: \.self) { zoom in
                Button {
                    store.dispatch(.setChartZoomLevel(level: zoom.level))
                } label: {
                    Text(zoom.label)
                        .font(isSelectedZoom(zoom) ? DOSTypography.caption.weight(.bold) : DOSTypography.caption)
                        .foregroundColor(isSelectedZoom(zoom) ? AmberTheme.amber : AmberTheme.amberDark)
                        .padding(.vertical, DOSSpacing.sm)
                        .padding(.horizontal, DOSSpacing.xs)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(AmberTheme.amber)
                                .frame(height: 2)
                                .opacity(isSelectedZoom(zoom) ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(zoom.label)
                .accessibilityAddTraits(isSelectedZoom(zoom) ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func isSelectedZoom(_ zoom: ZoomLevel) -> Bool {
        store.state.chartZoomLevel == zoom.level
    }
}

// MARK: - ZoomLevel

private enum ZoomLevel: CaseIterable {
    case three, six, twelve, twentyFour

    var level: Int {
        switch self {
        case .three: return 3
        case .six: return 6
        case .twelve: return 12
        case .twentyFour: return 24
        }
    }

    var label: String {
        "\(level)h"
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
