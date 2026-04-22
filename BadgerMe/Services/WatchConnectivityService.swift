//
//  WatchConnectivityService.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import WatchConnectivity

/// Manages bidirectional communication with the Watch app.
/// Sends active Badger state to Watch and receives acknowledgment actions.
@Observable
@MainActor
final class WatchConnectivityService: NSObject {

    private var session: WCSession?
    private(set) var isReachable = false

    /// Callback for when the Watch sends an acknowledgment action.
    /// Routed to BadgerEngine for processing.
    var onWatchAction: ((WatchAction) async -> Void)?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
        }
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send to Watch

    /// Sends a summary of active Badgers to the Watch for display.
    func sendActiveBadgers(_ badgers: [Badger]) {
        guard let session, session.isReachable else { return }

        let summaries: [[String: Any]] = badgers.map { badger in
            [
                "id": badger.id.uuidString,
                "title": badger.title,
                "state": badger.state.rawValue,
                "currentLevel": badger.currentLevel,
                "startsAt": badger.startsAt.timeIntervalSince1970,
            ]
        }

        session.sendMessage(["activeBadgers": summaries], replyHandler: nil) { error in
            print("Watch send error: \(error)")
        }
    }

    /// Sends a single Badger state update to the Watch (e.g., after acknowledgment).
    func sendBadgerUpdate(badgerId: UUID, newState: BadgerState) {
        guard let session, session.isReachable else { return }

        session.sendMessage([
            "badgerUpdate": [
                "id": badgerId.uuidString,
                "state": newState.rawValue,
            ]
        ], replyHandler: nil) { error in
            print("Watch update error: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            print("WCSession activation error: \(error)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for switching paired watches
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    /// Receives messages from the Watch (acknowledgment actions).
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let actionString = message["action"] as? String,
              let badgerIdString = message["badgerId"] as? String,
              let badgerId = UUID(uuidString: badgerIdString) else {
            return
        }

        let action: WatchAction
        switch actionString {
        case "done":
            action = WatchAction(badgerId: badgerId, type: .done)
        case "dismiss":
            action = WatchAction(badgerId: badgerId, type: .dismiss)
        case "snooze":
            let minutes = message["snoozeDuration"] as? Int ?? 15
            action = WatchAction(badgerId: badgerId, type: .snooze(minutes: minutes))
        default:
            return
        }

        Task { @MainActor in
            await self.onWatchAction?(action)
        }
    }
}

// MARK: - Watch Action

struct WatchAction {
    let badgerId: UUID
    let type: WatchActionType
}

enum WatchActionType {
    case done
    case dismiss
    case snooze(minutes: Int)
}
