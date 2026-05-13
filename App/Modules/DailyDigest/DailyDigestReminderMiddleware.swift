//
//  DailyDigestReminderMiddleware.swift
//  DOSBTSApp
//
//  Schedules a daily local notification that nudges the user to open the
//  Daily Digest tab. Identifier is stable so re-scheduling replaces the
//  previous request cleanly.
//

import Combine
import Foundation
import UserNotifications

private let dailyDigestReminderIdentifier = "daily-digest-reminder"

func dailyDigestReminderMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            scheduleOrCancel(hour: state.dailyDigestReminderHour, minute: state.dailyDigestReminderMinute)
            return Empty().eraseToAnyPublisher()

        case .setDailyDigestReminderTime(hour: let hour, minute: let minute):
            scheduleOrCancel(hour: hour, minute: minute)
            return Empty().eraseToAnyPublisher()

        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

private func scheduleOrCancel(hour: Int?, minute: Int?) {
    guard let hour = hour, let minute = minute else {
        DirectNotifications.shared.removeNotification(identifier: dailyDigestReminderIdentifier)
        return
    }

    DirectNotifications.shared.ensureCanSendNotification { notificationState in
        guard notificationState != .none else {
            DirectLog.info("DailyDigestReminder: notifications not authorized, skipping schedule")
            return
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = LocalizedString("Your daily digest is ready")
        content.body = LocalizedString("Tap to review yesterday's glucose, meals, and insulin.")
        content.userInfo = ["action": "openDailyDigest"]
        if notificationState == .sound {
            content.sound = .default
        }

        DirectNotifications.shared.addNotification(
            identifier: dailyDigestReminderIdentifier,
            content: content,
            trigger: trigger
        )
    }
}
