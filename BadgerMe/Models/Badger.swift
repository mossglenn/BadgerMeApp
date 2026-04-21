//
//  Badger.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import SwiftData

@Model
final class Badger {
    var id: UUID
    var title: String
    var notes: String?
    var createdAt: Date
    var startsAt: Date
    var state: BadgerState
    var currentLevel: Int
    var snoozeCount: Int
    var acknowledgedAt: Date?
    var sourceType: TriggerSource
    var sourceIdentifier: String?

    // If nil, inherits from global default ladder
    var customLadder: EscalationLadder?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        createdAt: Date = Date(),
        startsAt: Date = Date(),
        state: BadgerState = .active,
        currentLevel: Int = 0,
        snoozeCount: Int = 0,
        acknowledgedAt: Date? = nil,
        sourceType: TriggerSource = .manual,
        sourceIdentifier: String? = nil,
        customLadder: EscalationLadder? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.startsAt = startsAt
        self.state = state
        self.currentLevel = currentLevel
        self.snoozeCount = snoozeCount
        self.acknowledgedAt = acknowledgedAt
        self.sourceType = sourceType
        self.sourceIdentifier = sourceIdentifier
        self.customLadder = customLadder
    }

    // MARK: - Computed Properties

    var isOverdue: Bool {
        state == .active && startsAt < Date()
    }

    /// Returns the date of the next escalation, based on the current level
    /// and the ladder assigned to this Badger. Returns nil if no ladder is available
    /// or all levels have been exhausted.
    func nextEscalationAt(using ladder: EscalationLadder) -> Date? {
        let levels = ladder.levels.sorted { $0.order < $1.order }
        guard currentLevel < levels.count else { return nil }

        var cumulativeSeconds = 0
        for i in 0...currentLevel {
            cumulativeSeconds += levels[i].waitDurationSeconds
        }
        return startsAt.addingTimeInterval(TimeInterval(cumulativeSeconds))
    }
}

// MARK: - BadgerState

enum BadgerState: String, Codable, CaseIterable {
    case active
    case snoozed
    case completed
    case dismissed
    case abandoned
}

// MARK: - TriggerSource

enum TriggerSource: String, Codable, CaseIterable {
    case manual
    case reminders
    case webhook
}
