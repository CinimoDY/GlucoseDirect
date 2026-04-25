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

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(markerGroups) { group in
                markerView(for: group)
                    .position(x: xPosition(for: group.time), y: laneHeight / 2)
                    .frame(width: 88, height: 48)
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

    @ViewBuilder
    private func markerView(for group: ConsolidatedMarkerGroup) -> some View {
        if group.isSingle, let marker = group.markers.first {
            Image(systemName: marker.type.icon)
                .font(.system(size: iconSize))
                .foregroundStyle(marker.type.color)
                .overlay(scoredMealCue(for: group), alignment: .bottomTrailing)
        } else {
            ZStack {
                ForEach(Array(group.markers.sorted(by: stackOrder).prefix(3).enumerated()), id: \.offset) { idx, marker in
                    Image(systemName: marker.type.icon)
                        .font(.system(size: iconSize))
                        .foregroundStyle(marker.type.color)
                        .offset(y: CGFloat(idx) * -3)
                }
                Text("\(group.markers.count)")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(group.dominantType.color))
                    .offset(x: 14, y: 12)
            }
        }
    }

    private func stackOrder(_ a: EventMarker, _ b: EventMarker) -> Bool {
        priority(a.type) < priority(b.type)
    }

    private func priority(_ t: EventMarkerType) -> Int {
        switch t {
        case .bolus: return 0
        case .meal: return 1
        case .exercise: return 2
        }
    }

    @ViewBuilder
    private func scoredMealCue(for group: ConsolidatedMarkerGroup) -> some View {
        if group.isSingle, group.markers[0].type == .meal,
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
