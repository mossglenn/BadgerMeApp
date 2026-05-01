//
//  WebhookSettingsView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct WebhookSettingsView: View {
    @AppStorage(AppSettings.Key.webhookListenerEnabled) private var enabled = false
    @AppStorage(AppSettings.Key.webhookPort) private var port = 8765

    @State private var authToken: String = ""
    @State private var showingToken = false
    @State private var showingRegenConfirm = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Webhook Listener", isOn: $enabled)
            } header: {
                Text("Listener")
            } footer: {
                Text("Listens for incoming Badger requests on your local network. Requires the app to be running.")
            }

            if enabled {
                Section {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("Port", value: $port, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("POST to http://[device-ip]:\(port)/badger")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Configuration")
                }

                Section {
                    if showingToken {
                        HStack {
                            Text(authToken.isEmpty ? "No token generated" : authToken)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = authToken
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    } else {
                        Button("Show Auth Token") {
                            loadToken()
                            showingToken = true
                        }
                    }

                    Button("Regenerate Token") {
                        showingRegenConfirm = true
                    }
                    .foregroundStyle(.orange)
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Include this token in webhook requests for authentication. Stored securely in Keychain.")
                }

                Section {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Security")
                                .font(.subheadline.weight(.medium))
                            Text("Token stored in Keychain. Listener bound to local network only. Rate limited to 10 requests/minute.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Payload Example") {
                    Text("""
                    {
                      "title": "Task name",
                      "notes": "Optional details",
                      "token": "<your-token>"
                    }
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Webhook")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Regenerate Auth Token?",
            isPresented: $showingRegenConfirm,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                regenerateToken()
            }
        } message: {
            Text("Existing automation integrations will stop working until updated with the new token.")
        }
        .onAppear {
            loadToken()
        }
    }

    // MARK: - Token Management (Keychain)

    private func loadToken() {
        // Migrate legacy UserDefaults token to Keychain
        if let legacy = UserDefaults.standard.string(forKey: "webhookAuthToken") {
            KeychainHelper.setString(legacy, forKey: "webhookAuthToken")
            UserDefaults.standard.removeObject(forKey: "webhookAuthToken")
        }

        if let saved = KeychainHelper.string(forKey: "webhookAuthToken") {
            authToken = saved
        } else {
            regenerateToken()
        }
    }

    private func regenerateToken() {
        authToken = UUID().uuidString
        KeychainHelper.setString(authToken, forKey: "webhookAuthToken")
        showingToken = true
    }
}
