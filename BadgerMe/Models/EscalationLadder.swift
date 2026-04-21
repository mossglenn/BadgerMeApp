//
//  EscalationLadder.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import SwiftData

@Model
final class EscalationLadder {
    var id: UUID
    var name: String
    var levels: [EscalationLevel]
    var nuclearOption: NuclearOption
    var maxSnoozeCount: Int
    var snoozeRestartLevel: Int

    init(
        id: UUID = UUID(),
        name: String,
        levels: [EscalationLevel],
        nuclearOption: NuclearOption = .repeatForever,
        maxSnoozeCount: Int = 3,
        snoozeRestartLevel: Int = 0
    ) {
        self.id = id
        self.name = name
        self.levels = levels
        self.nuclearOption = nuclearOption
        self.maxSnoozeCount = maxSnoozeCount
        self.snoozeRestartLevel = snoozeRestartLevel
    }
}

// MARK: - EscalationLevel

struct EscalationLevel: Codable, Identifiable, Hashable {
    var id: UUID
    var order: Int
    var waitDurationSeconds: Int
    var actions: [EscalationAction]

    init(
        id: UUID = UUID(),
        order: Int,
        waitDurationSeconds: Int,
        actions: [EscalationAction]
    ) {
        self.id = id
        self.order = order
        self.waitDurationSeconds = waitDurationSeconds
        self.actions = actions
    }
}

// MARK: - EscalationAction

struct EscalationAction: Codable, Hashable {
    var type: ActionType
    var config: ActionConfig

    init(type: ActionType, config: ActionConfig = ActionConfig()) {
        self.type = type
        self.config = config
    }
}

// MARK: - ActionType

enum ActionType: String, Codable, CaseIterable {
    case sound
    case speakText
    case torchFlash
    case notificationBanner
}

// MARK: - ActionConfig

struct ActionConfig: Codable, Hashable {
    var soundName: String?
    var soundVolume: Float?
    var speechText: String?
    var speechVolume: Float?
    var torchDuration: Double?
    var notificationTitle: String?
    var notificationBody: String?
    var interruptionLevel: InterruptionLevelOption?

    init(
        soundName: String? = nil,
        soundVolume: Float? = nil,
        speechText: String? = nil,
        speechVolume: Float? = nil,
        torchDuration: Double? = nil,
        notificationTitle: String? = nil,
        notificationBody: String? = nil,
        interruptionLevel: InterruptionLevelOption? = nil
    ) {
        self.soundName = soundName
        self.soundVolume = soundVolume
        self.speechText = speechText
        self.speechVolume = speechVolume
        self.torchDuration = torchDuration
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.interruptionLevel = interruptionLevel
    }
}

// MARK: - InterruptionLevelOption

enum InterruptionLevelOption: String, Codable, CaseIterable {
    case active
    case timeSensitive
}

// MARK: - NuclearOption

enum NuclearOption: String, Codable, CaseIterable {
    case repeatForever
    case giveUp
    case notifyContact
}
