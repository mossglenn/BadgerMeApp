//
//  BadgerEvent.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import SwiftData

@Model
final class BadgerEvent {
    var id: UUID
    var badgerId: UUID
    var timestamp: Date
    var eventType: BadgerEventType
    var levelAtEvent: Int
    var notes: String?

    init(
        id: UUID = UUID(),
        badgerId: UUID,
        timestamp: Date = Date(),
        eventType: BadgerEventType,
        levelAtEvent: Int,
        notes: String? = nil
    ) {
        self.id = id
        self.badgerId = badgerId
        self.timestamp = timestamp
        self.eventType = eventType
        self.levelAtEvent = levelAtEvent
        self.notes = notes
    }
}

// MARK: - BadgerEventType

enum BadgerEventType: String, Codable, CaseIterable {
    case created
    case levelFired
    case snoozed
    case completed
    case dismissed
    case abandoned
    case escalated
}
