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

// MARK: - App Group key constants

/// Raw string keys for the day/night alarm profile data mirrored into
/// `UserDefaults.shared` (App Group suite). Both the app's
/// AppGroupSharing middleware and the widget targets read/write these
/// keys directly via `UserDefaults.shared.set(_:forKey:)`.
enum AppGroupAlarmProfileKeys {
    static let dayAlarmHigh = "dayAlarmHigh"
    static let dayAlarmLow = "dayAlarmLow"
    static let nightAlarmHigh = "nightAlarmHigh"
    static let nightAlarmLow = "nightAlarmLow"
    static let nightStartHour = "nightStartHour"
    static let nightStartMinute = "nightStartMinute"
    static let nightEndHour = "nightEndHour"
    static let nightEndMinute = "nightEndMinute"
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
    // Clamp inputs to valid ranges so a corrupted UserDefaults state can't produce
    // nonsense schedules. DatePicker can't surface out-of-range values; this guards
    // against direct manipulation or future code paths.
    let sH = max(0, min(23, nightStartHour))
    let sM = max(0, min(59, nightStartMinute))
    let eH = max(0, min(23, nightEndHour))
    let eM = max(0, min(59, nightEndMinute))
    let startMinute = (sH * 60) + sM
    let endMinute = (eH * 60) + eM

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
