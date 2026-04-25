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
    let onTapGroup: (ConsolidatedMarkerGroup) -> Void

    private let laneHeight: CGFloat = 48
    private let iconSize: CGFloat = 22
    private let yAxisPadding: CGFloat = 30
    private let touchTargetWidth: CGFloat = 88
    private let touchTargetHeight: CGFloat = 48

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(markerGroups) { group in
                markerView(for: group)
                    .position(x: xPosition(for: group.time), y: laneHeight / 2)
                    .frame(width: touchTargetWidth, height: touchTargetHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapGroup(group) }
                    .accessibilityLabel(accessibilityLabel(for: group))
                    .accessibilityAddTraits(.isButton)
            }
        }
        .frame(height: laneHeight)
        .padding(.trailing, yAxisPadding)
        .clipped()
    }

    /// One icon per batch (per the v2 design):
    /// - Single type, single entry → that type's icon
    /// - Single type, multiple entries → that type's icon + circular border
    /// - Mixed food + insulin (any count) → CombinedFoodInsulinIcon
    /// - Mixed types involving exercise → fall back to dominant-type icon
    ///
    /// The border is the "this is a batch" cue; we no longer stack icons
    /// or show a count badge.
    @ViewBuilder
    private func markerView(for group: ConsolidatedMarkerGroup) -> some View {
        let types = Set(group.markers.map(\.type))
        let isBatch = group.markers.count > 1
        let isMixedFoodInsulin = types.contains(.meal) && types.contains(.bolus)

        Group {
            if isMixedFoodInsulin {
                CombinedFoodInsulinIcon(size: iconSize)
            } else if types.contains(.meal) {
                AppleIcon()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(EventMarkerType.meal.color)
            } else if types.contains(.bolus) {
                Image(systemName: EventMarkerType.bolus.icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(EventMarkerType.bolus.color)
            } else if types.contains(.exercise) {
                Image(systemName: EventMarkerType.exercise.icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(EventMarkerType.exercise.color)
            }
        }
        .padding(6)
        .background(
            Circle()
                .stroke(borderColor(for: types), lineWidth: 1.5)
                .opacity(isBatch ? 1 : 0)
        )
        .overlay(scoredMealCue(for: group), alignment: .bottomTrailing)
    }

    private func borderColor(for types: Set<EventMarkerType>) -> Color {
        if types.contains(.meal) && types.contains(.bolus) {
            return AmberTheme.amber
        } else if types.contains(.meal) {
            return EventMarkerType.meal.color
        } else if types.contains(.bolus) {
            return EventMarkerType.bolus.color
        }
        return EventMarkerType.exercise.color
    }

    @ViewBuilder
    private func scoredMealCue(for group: ConsolidatedMarkerGroup) -> some View {
        if group.isSingle,
           group.markers[0].type == .meal,
           scoredMealEntryIds.contains(group.markers[0].sourceID) {
            Circle().fill(AmberTheme.amber).frame(width: 4, height: 4)
        }
    }

    private func accessibilityLabel(for group: ConsolidatedMarkerGroup) -> String {
        if group.isSingle, let m = group.markers.first {
            switch m.type {
            case .meal: return "Meal at \(m.time.toLocalTime())"
            case .bolus: return "Insulin at \(m.time.toLocalTime())"
            case .exercise: return "Exercise at \(m.time.toLocalTime())"
            }
        }
        return "\(group.markers.count) entries at \(group.time.toLocalTime())"
    }

    private func xPosition(for time: Date) -> CGFloat {
        let totalDuration = timeRange.upperBound.timeIntervalSince(timeRange.lowerBound)
        guard totalDuration > 0 else { return 0 }
        let offset = time.timeIntervalSince(timeRange.lowerBound)
        let adjustedWidth = totalWidth - yAxisPadding
        return (offset / totalDuration) * adjustedWidth
    }
}
