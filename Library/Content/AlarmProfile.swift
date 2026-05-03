//
//  AlarmProfile.swift
//  DOSBTS
//
//  Day/night alarm profile resolution. Shared between app and widget targets.
//

import Foundation

// MARK: - AlarmProfile

enum AlarmProfile {
    case day
    case night
}

// MARK: - Resolution

/// Returns the active alarm profile for the given clock time and night-window schedule.
///
/// Window semantics: `[start, end)` — start is inclusive, end is exclusive.
/// Wrap across midnight (e.g., 22:00→07:00) is handled via minute-of-day comparison.
/// A degenerate schedule where `start == end` returns `.day` always (no slot is "night").
func resolveActiveAlarmProfile(
    at date: Date,
    nightStartHour: Int,
    nightStartMinute: Int,
    nightEndHour: Int,
    nightEndMinute: Int
) -> AlarmProfile {
    let startMinute = (nightStartHour * 60) + nightStartMinute
    let endMinute = (nightEndHour * 60) + nightEndMinute

    if startMinute == endMinute {
        return .day
    }

    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    let currentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

    if startMinute < endMinute {
        // Same-day window, e.g. 13:00 → 18:00
        return (currentMinute >= startMinute && currentMinute < endMinute) ? .night : .day
    } else {
        // Wraps midnight, e.g. 22:00 → 07:00
        return (currentMinute >= startMinute || currentMinute < endMinute) ? .night : .day
    }
}
