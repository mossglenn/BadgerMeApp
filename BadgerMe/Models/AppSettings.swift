//
//  AppSettings.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation

/// App-wide settings stored in UserDefaults via @AppStorage.
/// Not a SwiftData model — settings are global, not relational.
struct AppSettings {
    static let defaultSnoozeDurations = [5, 15, 30, 60] // minutes

    // MARK: - UserDefaults Keys

    enum Key {
        static let defaultLadderId = "defaultLadderId"
        static let reminderPollingEnabled = "reminderPollingEnabled"
        static let reminderListIdentifiers = "reminderListIdentifiers"
        static let webhookListenerEnabled = "webhookListenerEnabled"
        static let webhookPort = "webhookPort"
        static let snoozeDurations = "snoozeDurations"
        static let timeSensitiveRequested = "timeSensitiveRequested"
        static let onboardingComplete = "onboardingComplete"
    }

    // MARK: - Defaults

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.reminderPollingEnabled: false,
            Key.webhookListenerEnabled: false,
            Key.webhookPort: 8765,
            Key.snoozeDurations: defaultSnoozeDurations,
            Key.timeSensitiveRequested: false,
            Key.onboardingComplete: false,
        ])
    }
}
