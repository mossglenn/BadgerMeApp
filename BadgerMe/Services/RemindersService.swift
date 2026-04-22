//
//  RemindersService.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import EventKit
import Foundation

/// Wraps EventKit to detect overdue Apple Reminders and create Badgers for them.
/// Polls on app foreground and via BGAppRefreshTask.
@Observable
@MainActor
final class RemindersService {

    private let eventStore = EKEventStore()
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var availableLists: [ReminderList] = []

    // MARK: - Authorization

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            if granted {
                loadAvailableLists()
            }
            return granted
        } catch {
            print("Reminders access error: \(error)")
            authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            return false
        }
    }

    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    // MARK: - List Discovery

    func loadAvailableLists() {
        let calendars = eventStore.calendars(for: .reminder)
        availableLists = calendars.map { calendar in
            ReminderList(
                identifier: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendar.cgColor
            )
        }
    }

    // MARK: - Polling

    /// Fetches overdue, incomplete reminders from the configured lists.
    func fetchOverdueReminders(from listIdentifiers: [String]) async -> [OverdueReminder] {
        guard authorizationStatus == .fullAccess else { return [] }

        let calendars = eventStore.calendars(for: .reminder).filter {
            listIdentifiers.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: Date(),
            calendars: calendars
        )

        guard let reminders = await fetchReminders(matching: predicate) else {
            return []
        }

        return reminders.compactMap { reminder in
            // Only include reminders that actually have a due date and are overdue
            guard let dueDate = reminder.dueDateComponents,
                  let date = Calendar.current.date(from: dueDate),
                  date <= Date() else {
                return nil
            }

            return OverdueReminder(
                identifier: reminder.calendarItemIdentifier,
                title: reminder.title ?? "Untitled Reminder",
                notes: reminder.notes,
                dueDate: date,
                listTitle: reminder.calendar?.title
            )
        }
    }

    /// Creates Badgers for newly overdue reminders, skipping any that already
    /// have an active Badger (deduplication by sourceIdentifier).
    func pollAndCreateBadgers(engine: BadgerEngine, listIdentifiers: [String]) async {
        let overdueReminders = await fetchOverdueReminders(from: listIdentifiers)

        for reminder in overdueReminders {
            // Check deduplication — skip if a Badger already exists for this reminder
            guard !engine.hasBadger(forSourceIdentifier: reminder.identifier) else {
                continue
            }

            await engine.createBadger(
                title: reminder.title,
                notes: reminder.notes,
                startsAt: Date(),
                sourceType: .reminders,
                sourceIdentifier: reminder.identifier
            )
        }
    }

    // MARK: - Completion Sync

    /// Marks a Reminder as complete in EventKit when its Badger is marked Done.
    func markComplete(reminderIdentifier: String) async throws {
        guard authorizationStatus == .fullAccess else { return }

        let predicate = eventStore.predicateForReminders(in: nil)
        guard let reminders = await fetchReminders(matching: predicate) else { return }

        guard let reminder = reminders.first(where: {
            $0.calendarItemIdentifier == reminderIdentifier
        }) else { return }

        reminder.isCompleted = true
        reminder.completionDate = Date()
        try eventStore.save(reminder, commit: true)
    }

    // MARK: - Private

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder]? {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders)
            }
        }
    }
}

// MARK: - Supporting Types

struct ReminderList: Identifiable {
    let identifier: String
    let title: String
    let color: CGColor?

    var id: String { identifier }
}

struct OverdueReminder {
    let identifier: String
    let title: String
    let notes: String?
    let dueDate: Date
    let listTitle: String?
}
