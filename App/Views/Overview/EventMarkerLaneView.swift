//
//  EventMarkerLaneView.swift
//  DOSBTS
//

import SwiftUI

struct EventMarkerLaneView: View {
    let markerGroups: [ConsolidatedMarkerGroup]
    let totalWidth: CGFloat
    let timeRange: ClosedRange<Date>
    let scoredMealEntryIds: Set<UUID>
    let onTapMeal: (UUID) -> Void
    let onTapInsulin: (UUID) -> Void
    @Binding var expandedGroupID: String?

    private let laneHeight: CGFloat = 32
    private let yAxisPadding: CGFloat = 30

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Marker icons
            ForEach(markerGroups) { group in
                markerView(for: group)
                    .position(x: xPosition(for: group.time), y: laneHeight / 2)
            }

            // Expanded detail overlay
            if let expandedID = expandedGroupID,
               let group = markerGroups.first(where: { $0.id == expandedID }) {
                expandedPanel(for: group)
                    .position(x: clampedPanelX(for: group.time), y: laneHeight + 4)
                    .zIndex(10)
            }
        }
        .frame(height: laneHeight)
        .padding(.trailing, yAxisPadding)
        .clipped()
    }

    // MARK: - Marker View

    @ViewBuilder
    private func markerView(for group: ConsolidatedMarkerGroup) -> some View {
        let isExpanded = expandedGroupID == group.id

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if group.isSingle {
                    tapSingleMarker(group.markers[0])
                } else {
                    expandedGroupID = isExpanded ? nil : group.id
                }
            }
        } label: {
            HStack(spacing: 2) {
                if group.isSingle {
                    let marker = group.markers[0]
                    Image(systemName: marker.type.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(marker.type.color)
                    Text(marker.label)
                        .font(DOSTypography.caption)
                        .foregroundColor(marker.type.color)
                        .bold()
                } else {
                    // Consolidated: show dominant icon + summary
                    Image(systemName: group.dominantType.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(group.dominantType.color)
                    Text(group.summaryLabel)
                        .font(DOSTypography.caption)
                        .foregroundColor(group.dominantType.color)
                        .bold()
                    // Badge count
                    Text("\(group.markers.count)")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(width: 14, height: 14)
                        .background(group.dominantType.color)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.6))
            .cornerRadius(3)
            .overlay(
                // Scored meal visual cue: subtle amber border
                Group {
                    if group.isSingle,
                       group.markers[0].type == .meal,
                       scoredMealEntryIds.contains(group.markers[0].sourceID) {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(AmberTheme.amber.opacity(0.5), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Panel

    @ViewBuilder
    private func expandedPanel(for group: ConsolidatedMarkerGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(group.markers) { marker in
                Button {
                    tapSingleMarker(marker)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        expandedGroupID = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: marker.type.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(marker.type.color)
                            .frame(width: 14)
                        Text(marker.label)
                            .font(DOSTypography.caption)
                            .foregroundColor(marker.type.color)
                            .bold()
                        Text(marker.time.toLocalTime())
                            .font(.system(size: 9))
                            .foregroundColor(AmberTheme.amberDark)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AmberTheme.dosBlack.opacity(0.9))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(AmberTheme.amberDark.opacity(0.4), lineWidth: 0.5)
        )
        .cornerRadius(4)
    }

    // MARK: - Positioning

    private func xPosition(for time: Date) -> CGFloat {
        let totalDuration = timeRange.upperBound.timeIntervalSince(timeRange.lowerBound)
        guard totalDuration > 0 else { return 0 }
        let offset = time.timeIntervalSince(timeRange.lowerBound)
        let adjustedWidth = totalWidth - yAxisPadding
        return (offset / totalDuration) * adjustedWidth
    }

    private func clampedPanelX(for time: Date) -> CGFloat {
        let x = xPosition(for: time)
        let panelHalfWidth: CGFloat = 60
        let adjustedWidth = totalWidth - yAxisPadding
        return max(panelHalfWidth, min(x, adjustedWidth - panelHalfWidth))
    }

    // MARK: - Tap Handling

    private func tapSingleMarker(_ marker: EventMarker) {
        switch marker.type {
        case .meal:
            onTapMeal(marker.sourceID)
        case .bolus:
            onTapInsulin(marker.sourceID)
        case .exercise:
            break
        }
    }
}
