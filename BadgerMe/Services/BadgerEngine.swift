//
//  BadgerEngine.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import SwiftData
import UserNotifications

@Observable
@MainActor
final class BadgerEngine {

    private let modelContext: ModelContext
    private let notificationService: NotificationService

    // MARK: - Observable State

    private(set) var activeBadgers: [Badger] = []
    private(set) var snoozedBadgers: [Badger] = []
    private(set) var recentHistory: [Badger] = []

    init(modelContext: ModelContext, notificationService: NotificationService = .shared) {
        self.modelContext = modelContext
        self.notificationService = notificationService

        notificationService.onNotificationResponse = { [weak self] response in
            await self?.handleNotificationResponse(response)
        }

        refreshBadgers()
    }

    // MARK: - Create

    func createBadger(
        title: String,
        notes: String? = nil,
        startsAt: Date = Date(),
        sourceType: TriggerSource = .manual,
        sourceIdentifier: String? = nil,
        customLadder: EscalationLadder? = nil
    ) async {
        let badger = Badger(
            title: title,
            notes: notes,
            startsAt: startsAt,
            sourceType: sourceType,
            sourceIdentifier: sourceIdentifier,
            customLadder: customLadder
        )

        modelContext.insert(badger)
        saveContext()

        logEvent(for: badger, type: .created)

        // Schedule notifications using the Badger's custom ladder or the default
        let ladder = try? resolvedLadder(for: badger)
        if let ladder {
            try? await notificationService.scheduleLadder(for: badger, ladder: ladder)
        }

        refreshBadgers()
    }

    // MARK: - Acknowledge

    func markDone(_ badger: Badger) async {
        badger.state = .completed
        badger.acknowledgedAt = Date()
        saveContext()

        logEvent(for: badger, type: .completed)
        notificationService.cancelAll(for: badger.id)
        refreshBadgers()
    }

    func snooze(_ badger: Badger, durationMinutes: Int) async {
        badger.state = .snoozed
        badger.snoozeCount += 1
        saveContext()

        logEvent(for: badger, type: .snoozed, notes: "\(durationMinutes) minutes")

        let snoozeUntil = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))

        // Determine restart level based on snooze count
        if let ladder = try? resolvedLadder(for: badger) {
            let restartLevel: Int
            if badger.snoozeCount >= ladder.maxSnoozeCount {
                // Escalate: restart from a higher level after too many snoozes
                restartLevel = min(ladder.snoozeRestartLevel + 1, ladder.levels.count - 1)
            } else {
                restartLevel = ladder.snoozeRestartLevel
            }

            badger.currentLevel = restartLevel
            badger.state = .active
            badger.startsAt = snoozeUntil
            saveContext()

            try? await notificationService.rescheduleAfterSnooze(
                for: badger,
                ladder: ladder,
                restartFromLevel: restartLevel,
                snoozeUntil: snoozeUntil
            )
        }

        refreshBadgers()
    }

    func dismiss(_ badger: Badger) {
        badger.state = .dismissed
        badger.acknowledgedAt = Date()
        saveContext()

        logEvent(for: badger, type: .dismissed)
        notificationService.cancelAll(for: badger.id)
        refreshBadgers()
    }

    func abandon(_ badger: Badger) {
        badger.state = .abandoned
        badger.acknowledgedAt = Date()
        saveContext()

        logEvent(for: badger, type: .abandoned)
        notificationService.cancelAll(for: badger.id)
        refreshBadgers()
    }

    // MARK: - Edit & Delete

    func deleteBadger(_ badger: Badger) {
        notificationService.cancelAll(for: badger.id)
        modelContext.delete(badger)
        saveContext()
        refreshBadgers()
    }

    // MARK: - Notification Response Handling

    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let badgerIdString = userInfo["badgerId"] as? String,
              let badgerId = UUID(uuidString: badgerIdString) else {
            return
        }

        guard let badger = fetchBadger(by: badgerId) else { return }

        switch response.actionIdentifier {
        case NotificationService.Action.done:
            await markDone(badger)

        case NotificationService.Action.dismiss:
            dismiss(badger)

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself (not an action button)
            // No state change — the app will open to show the Badger
            break

        case UNNotificationDismissActionIdentifier:
            // User swiped away the notification — treat as ignored, no state change
            break

        default:
            // Check for snooze actions (SNOOZE_5, SNOOZE_15, etc.)
            if response.actionIdentifier.hasPrefix("SNOOZE_"),
               let minutesString = response.actionIdentifier.split(separator: "_").last,
               let minutes = Int(minutesString) {
                await snooze(badger, durationMinutes: minutes)
            }
        }
    }

    // MARK: - Ladder Resolution

    /// Returns the ladder to use for a Badger: its custom ladder if set, otherwise the default.
    func resolvedLadder(for badger: Badger) throws -> EscalationLadder {
        if let custom = badger.customLadder {
            return custom
        }
        return try fetchDefaultLadder()
    }

    /// Fetches the default ladder. If none exists, creates the factory default.
    func fetchDefaultLadder() throws -> EscalationLadder {
        let defaultIdString = UserDefaults.standard.string(forKey: AppSettings.Key.defaultLadderId)
        let defaultId = defaultIdString.flatMap { UUID(uuidString: $0) }

        if let defaultId {
            let predicate = #Predicate<EscalationLadder> { $0.id == defaultId }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let ladder = try modelContext.fetch(descriptor).first {
                return ladder
            }
        }

        // No default ladder exists — create the factory default
        let ladder = Self.createFactoryDefaultLadder()
        modelContext.insert(ladder)
        saveContext()
        UserDefaults.standard.set(ladder.id.uuidString, forKey: AppSettings.Key.defaultLadderId)
        return ladder
    }

    // MARK: - Refresh

    func refreshBadgers() {
        do {
            let active = BadgerState.active
            let snoozed = BadgerState.snoozed
            let activePredicate = #Predicate<Badger> {
                $0.state == active || $0.state == snoozed
            }
            var activeDescriptor = FetchDescriptor(predicate: activePredicate)
            activeDescriptor.sortBy = [SortDescriptor(\.startsAt, order: .forward)]
            let allActive = try modelContext.fetch(activeDescriptor)

            activeBadgers = allActive.filter { $0.state == .active }
            snoozedBadgers = allActive.filter { $0.state == .snoozed }

            let completed = BadgerState.completed
            let dismissed = BadgerState.dismissed
            let abandoned = BadgerState.abandoned
            let historyPredicate = #Predicate<Badger> {
                $0.state == completed || $0.state == dismissed || $0.state == abandoned
            }
            var historyDescriptor = FetchDescriptor(predicate: historyPredicate)
            historyDescriptor.sortBy = [SortDescriptor(\.acknowledgedAt, order: .reverse)]
            historyDescriptor.fetchLimit = 50
            recentHistory = try modelContext.fetch(historyDescriptor)
        } catch {
            print("Failed to fetch Badgers: \(error)")
        }
    }

    // MARK: - Event Logging

    func fetchEvents(for badgerId: UUID) -> [BadgerEvent] {
        let predicate = #Predicate<BadgerEvent> { $0.badgerId == badgerId }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private Helpers

    private func fetchBadger(by id: UUID) -> Badger? {
        let predicate = #Predicate<Badger> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func logEvent(
        for badger: Badger,
        type: BadgerEventType,
        notes: String? = nil
    ) {
        let event = BadgerEvent(
            badgerId: badger.id,
            eventType: type,
            levelAtEvent: badger.currentLevel,
            notes: notes
        )
        modelContext.insert(event)
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // MARK: - Factory Default Ladder

    static func createFactoryDefaultLadder() -> EscalationLadder {
        let level1 = EscalationLevel(
            order: 0,
            waitDurationSeconds: 300, // 5 minutes
            actions: [
                EscalationAction(
                    type: .notificationBanner,
                    config: ActionConfig(interruptionLevel: .active)
                ),
                EscalationAction(
                    type: .sound,
                    config: ActionConfig(soundVolume: 0.5)
                ),
            ]
        )

        let level2 = EscalationLevel(
            order: 1,
            waitDurationSeconds: 600, // 10 minutes
            actions: [
                EscalationAction(
                    type: .notificationBanner,
                    config: ActionConfig(interruptionLevel: .timeSensitive)
                ),
                EscalationAction(
                    type: .sound,
                    config: ActionConfig(soundVolume: 0.8)
                ),
            ]
        )

        let level3 = EscalationLevel(
            order: 2,
            waitDurationSeconds: 900, // 15 minutes
            actions: [
                EscalationAction(
                    type: .notificationBanner,
                    config: ActionConfig(interruptionLevel: .timeSensitive)
                ),
                EscalationAction(
                    type: .speakText,
                    config: ActionConfig(speechVolume: 1.0)
                ),
                EscalationAction(
                    type: .sound,
                    config: ActionConfig(soundVolume: 1.0)
                ),
            ]
        )

        return EscalationLadder(
            name: "Default",
            levels: [level1, level2, level3],
            nuclearOption: .repeatForever,
            maxSnoozeCount: 3,
            snoozeRestartLevel: 0
        )
    }
}
