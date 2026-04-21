//
//  NotificationService.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    // MARK: - Notification Identifiers

    enum Category {
        static let badger = "BADGER"
    }

    enum Action {
        static let done = "DONE"
        static let snooze5 = "SNOOZE_5"
        static let snooze15 = "SNOOZE_15"
        static let snooze30 = "SNOOZE_30"
        static let snooze60 = "SNOOZE_60"
        static let dismiss = "DISMISS"
    }

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Category Registration

    /// Registers notification categories and actions. Call once at app launch.
    func registerCategories(snoozeDurations: [Int] = AppSettings.defaultSnoozeDurations) {
        let doneAction = UNNotificationAction(
            identifier: Action.done,
            title: "Done",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: Action.dismiss,
            title: "Dismiss",
            options: [.destructive]
        )

        // Build snooze actions from configured durations
        var snoozeActions: [UNNotificationAction] = []
        for minutes in snoozeDurations {
            let identifier = "SNOOZE_\(minutes)"
            let title = "Snooze \(minutes)m"
            let action = UNNotificationAction(
                identifier: identifier,
                title: title,
                options: []
            )
            snoozeActions.append(action)
        }

        // Order: Done first, then snooze options, then dismiss
        var allActions = [doneAction]
        allActions.append(contentsOf: snoozeActions)
        allActions.append(dismissAction)

        let badgerCategory = UNNotificationCategory(
            identifier: Category.badger,
            actions: allActions,
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([badgerCategory])
    }

    // MARK: - Scheduling

    /// Schedules the entire escalation ladder for a Badger as individual notification requests.
    /// Each level is scheduled at its cumulative time offset from the start time.
    /// Use `cancelAll(for:)` when the user acknowledges to remove remaining notifications.
    func scheduleLadder(for badger: Badger, ladder: EscalationLadder) async throws {
        let levels = ladder.levels.sorted { $0.order < $1.order }
        var cumulativeSeconds = 0

        for level in levels {
            let triggerDate = badger.startsAt.addingTimeInterval(TimeInterval(cumulativeSeconds))
            let identifier = notificationIdentifier(badgerId: badger.id, level: level.order)

            let content = buildContent(for: badger, level: level, ladder: ladder)

            // Only schedule if the trigger date is in the future
            if triggerDate > Date() {
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: triggerDate
                )
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )

                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )

                try await center.add(request)
            }

            cumulativeSeconds += level.waitDurationSeconds
        }

        // Schedule nuclear option if configured to repeat
        if ladder.nuclearOption == .repeatForever, let lastLevel = levels.last {
            try await scheduleNuclearRepeat(
                for: badger,
                level: lastLevel,
                ladder: ladder,
                startingAfterSeconds: cumulativeSeconds
            )
        }
    }

    /// Cancels all pending notifications for a specific Badger.
    func cancelAll(for badgerId: UUID) {
        // Get all pending requests, filter by badger ID prefix, and remove them
        let prefix = "badger-\(badgerId.uuidString)"
        center.getPendingNotificationRequests { [weak self] requests in
            let matchingIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            self?.center.removePendingNotificationRequests(withIdentifiers: matchingIds)
        }
    }

    /// Reschedules a Badger's ladder after a snooze, starting from the given level.
    func rescheduleAfterSnooze(
        for badger: Badger,
        ladder: EscalationLadder,
        restartFromLevel: Int,
        snoozeUntil: Date
    ) async throws {
        // Cancel any existing notifications for this Badger
        cancelAll(for: badger.id)

        let levels = ladder.levels
            .sorted { $0.order < $1.order }
            .filter { $0.order >= restartFromLevel }

        var cumulativeSeconds = 0

        for level in levels {
            let triggerDate = snoozeUntil.addingTimeInterval(TimeInterval(cumulativeSeconds))
            let identifier = notificationIdentifier(badgerId: badger.id, level: level.order)

            let content = buildContent(for: badger, level: level, ladder: ladder)

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
            cumulativeSeconds += level.waitDurationSeconds
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is delivered while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    /// Called when the user interacts with a notification (taps an action or the notification itself).
    /// The actual handling is delegated to BadgerEngine via a callback.
    var onNotificationResponse: ((UNNotificationResponse) async -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await onNotificationResponse?(response)
    }

    // MARK: - Private Helpers

    private func notificationIdentifier(badgerId: UUID, level: Int) -> String {
        "badger-\(badgerId.uuidString)-level-\(level)"
    }

    private func nuclearIdentifier(badgerId: UUID, index: Int) -> String {
        "badger-\(badgerId.uuidString)-nuclear-\(index)"
    }

    private func buildContent(
        for badger: Badger,
        level: EscalationLevel,
        ladder: EscalationLadder
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.badger

        // Use the first notificationBanner action's config for title/body, or fall back to defaults
        let bannerAction = level.actions.first { $0.type == .notificationBanner }
        content.title = bannerAction?.config.notificationTitle ?? badger.title
        content.body = bannerAction?.config.notificationBody
            ?? "Level \(level.order + 1) — \(badger.notes ?? "Tap to respond")"

        // Determine interruption level
        let levelConfig = level.actions.first { $0.config.interruptionLevel != nil }
        if levelConfig?.config.interruptionLevel == .timeSensitive {
            content.interruptionLevel = .timeSensitive
        } else {
            content.interruptionLevel = .active
        }

        // Set sound from first sound action config
        let soundAction = level.actions.first { $0.type == .sound }
        if let soundName = soundAction?.config.soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }

        // Carry Badger metadata in userInfo for stateless response handling
        content.userInfo = [
            "badgerId": badger.id.uuidString,
            "level": level.order,
            "title": badger.title,
            "sourceType": badger.sourceType.rawValue,
            "sourceIdentifier": badger.sourceIdentifier ?? "",
        ]

        return content
    }

    /// Schedules repeating nuclear notifications after the ladder is exhausted.
    /// iOS limits pending requests to 64 total, so we cap nuclear repeats.
    private func scheduleNuclearRepeat(
        for badger: Badger,
        level: EscalationLevel,
        ladder: EscalationLadder,
        startingAfterSeconds: Int
    ) async throws {
        let repeatInterval = level.waitDurationSeconds
        // Cap at 10 nuclear repeats to stay within the 64-notification system limit
        let maxRepeats = 10
        var offsetSeconds = startingAfterSeconds

        for i in 0..<maxRepeats {
            let triggerDate = badger.startsAt.addingTimeInterval(TimeInterval(offsetSeconds))
            guard triggerDate > Date() else {
                offsetSeconds += repeatInterval
                continue
            }

            let identifier = nuclearIdentifier(badgerId: badger.id, index: i)
            let content = buildContent(for: badger, level: level, ladder: ladder)
            content.body = "OVERDUE — \(badger.title)"

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            try await center.add(request)
            offsetSeconds += repeatInterval
        }
    }
}
