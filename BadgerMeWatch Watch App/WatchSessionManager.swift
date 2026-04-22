//
//  WatchSessionManager.swift
//  BadgerMeWatch Watch App
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import WatchConnectivity

/// Watch-side WCSession manager. Receives Badger state from the phone
/// and sends acknowledgment actions back.
@Observable
final class WatchSessionManager: NSObject {

    static let shared = WatchSessionManager()

    private(set) var activeBadgers: [WatchBadger] = []
    private var session: WCSession?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Send Actions to Phone

    func sendDone(badgerId: UUID) {
        sendAction("done", badgerId: badgerId)
    }

    func sendSnooze(badgerId: UUID, minutes: Int = 15) {
        sendAction("snooze", badgerId: badgerId, extra: ["snoozeDuration": minutes])
    }

    func sendDismiss(badgerId: UUID) {
        sendAction("dismiss", badgerId: badgerId)
    }

    private func sendAction(_ action: String, badgerId: UUID, extra: [String: Any] = [:]) {
        guard let session, session.isReachable else { return }

        var message: [String: Any] = [
            "action": action,
            "badgerId": badgerId.uuidString,
        ]
        for (key, value) in extra {
            message[key] = value
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("Watch send error: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            print("Watch WCSession activation error: \(error)")
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if let summaries = message["activeBadgers"] as? [[String: Any]] {
            let badgers = summaries.compactMap { WatchBadger(from: $0) }
            Task { @MainActor in
                self.activeBadgers = badgers
            }
        }

        if let update = message["badgerUpdate"] as? [String: Any],
           let idString = update["id"] as? String,
           let stateString = update["state"] as? String {
            Task { @MainActor in
                self.activeBadgers.removeAll { $0.id.uuidString == idString }
                // If it's still active/snoozed, update rather than remove
                if stateString == "active" || stateString == "snoozed",
                   let id = UUID(uuidString: idString) {
                    // Re-add with updated state (simplified)
                    let updated = WatchBadger(
                        id: id,
                        title: self.activeBadgers.first { $0.id == id }?.title ?? "Badger",
                        state: stateString,
                        currentLevel: 0,
                        startsAt: Date()
                    )
                    self.activeBadgers.append(updated)
                }
            }
        }
    }
}

// MARK: - Watch Badger Model

/// Lightweight Badger representation for the Watch (no SwiftData).
struct WatchBadger: Identifiable {
    let id: UUID
    let title: String
    let state: String
    let currentLevel: Int
    let startsAt: Date

    init(id: UUID, title: String, state: String, currentLevel: Int, startsAt: Date) {
        self.id = id
        self.title = title
        self.state = state
        self.currentLevel = currentLevel
        self.startsAt = startsAt
    }

    init?(from dict: [String: Any]) {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let title = dict["title"] as? String,
              let state = dict["state"] as? String,
              let currentLevel = dict["currentLevel"] as? Int,
              let startsAtInterval = dict["startsAt"] as? TimeInterval else {
            return nil
        }
        self.id = id
        self.title = title
        self.state = state
        self.currentLevel = currentLevel
        self.startsAt = Date(timeIntervalSince1970: startsAtInterval)
    }
}
