//
//  WebhookServer.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import Foundation
import Network

/// A lightweight HTTP server that listens on a local port for incoming
/// Badger trigger requests. Implemented with NWListener — no third-party
/// dependencies. Disabled by default; enabled in Settings.
@Observable
@MainActor
final class WebhookServer {

    private var listener: NWListener?
    private(set) var isRunning = false
    private(set) var lastError: String?

    /// Rate limiting: track request timestamps per IP
    private var requestTimestamps: [String: [Date]] = [:]
    private let maxRequestsPerMinute = 10

    /// Callback to create a Badger when a valid webhook is received.
    var onBadgerRequest: ((WebhookBadgerRequest) async -> Void)?

    // MARK: - Start / Stop

    func start(port: UInt16) {
        stop()

        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters, on: nwPort)

            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListenerState(state)
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleConnection(connection)
                }
            }

            listener.start(queue: .main)
            self.listener = listener
            isRunning = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: - Listener State

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            isRunning = true
            lastError = nil
        case .failed(let error):
            lastError = error.localizedDescription
            isRunning = false
        case .cancelled:
            isRunning = false
        default:
            break
        }
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        // Read the full HTTP request (up to 64KB)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            Task { @MainActor in
                if let error {
                    self?.sendResponse(connection: connection, status: 500, body: ["error": error.localizedDescription])
                    return
                }

                guard let data else {
                    self?.sendResponse(connection: connection, status: 400, body: ["error": "No data received"])
                    return
                }

                self?.processRequest(data: data, connection: connection)
            }
        }
    }

    private func processRequest(data: Data, connection: NWConnection) {
        // Parse the HTTP request to extract the body
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid request encoding"])
            return
        }

        // Extract remote IP for rate limiting
        let remoteIP = connection.endpoint.debugDescription
        if isRateLimited(ip: remoteIP) {
            sendResponse(connection: connection, status: 429, body: ["error": "Rate limited"])
            return
        }

        // Verify it's a POST request
        guard requestString.hasPrefix("POST") else {
            sendResponse(connection: connection, status: 405, body: ["error": "Only POST is supported"])
            return
        }

        // Extract JSON body (everything after the blank line in HTTP)
        guard let bodyRange = requestString.range(of: "\r\n\r\n") else {
            sendResponse(connection: connection, status: 400, body: ["error": "Malformed HTTP request"])
            return
        }
        let bodyString = String(requestString[bodyRange.upperBound...])
        guard let bodyData = bodyString.data(using: .utf8) else {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid body encoding"])
            return
        }

        // Decode the webhook payload
        let request: WebhookBadgerRequest
        do {
            request = try JSONDecoder().decode(WebhookBadgerRequest.self, from: bodyData)
        } catch {
            sendResponse(connection: connection, status: 400, body: ["error": "Invalid JSON: \(error.localizedDescription)"])
            return
        }

        // Validate auth token
        let storedToken = UserDefaults.standard.string(forKey: "webhookAuthToken") ?? ""
        guard request.token == storedToken, !storedToken.isEmpty else {
            sendResponse(connection: connection, status: 401, body: ["error": "Invalid or missing auth token"])
            return
        }

        // Create the Badger
        Task {
            await onBadgerRequest?(request)
            sendResponse(connection: connection, status: 201, body: [
                "status": "created",
                "title": request.title,
            ])
        }
    }

    // MARK: - HTTP Response

    private func sendResponse(connection: NWConnection, status: Int, body: [String: Any]) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 201: statusText = "Created"
        case 400: statusText = "Bad Request"
        case 401: statusText = "Unauthorized"
        case 405: statusText = "Method Not Allowed"
        case 429: statusText = "Too Many Requests"
        case 500: statusText = "Internal Server Error"
        default: statusText = "Unknown"
        }

        let jsonData = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let response = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: application/json\r
        Content-Length: \(jsonData.count)\r
        Connection: close\r
        \r
        \(jsonString)
        """

        if let responseData = response.data(using: .utf8) {
            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Rate Limiting

    private func isRateLimited(ip: String) -> Bool {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        // Clean old timestamps
        requestTimestamps[ip] = (requestTimestamps[ip] ?? []).filter { $0 > oneMinuteAgo }

        let recentCount = requestTimestamps[ip]?.count ?? 0
        if recentCount >= maxRequestsPerMinute {
            return true
        }

        requestTimestamps[ip, default: []].append(now)
        return false
    }
}

// MARK: - Webhook Payload

struct WebhookBadgerRequest: Decodable {
    let title: String
    var notes: String?
    var ladderId: UUID?
    var callbackURL: URL?
    let token: String
}
