//
//  SettingsView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI
import SwiftData
import UserNotifications
import EventKit

struct SettingsView: View {
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppSettings.Key.reminderPollingEnabled) private var reminderPollingEnabled = false
    @AppStorage(AppSettings.Key.webhookListenerEnabled) private var webhookListenerEnabled = false
    @AppStorage(AppSettings.Key.webhookPort) private var webhookPort = 8765
    @AppStorage(AppSettings.Key.timeSensitiveRequested) private var timeSensitiveRequested = false

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var snoozeDurations: [Int] = AppSettings.defaultSnoozeDurations
    @State private var defaultLadder: EscalationLadder?
    @State private var remindersService = RemindersService()
    @State private var selectedListIds: Set<String> = []

    var body: some View {
        Form {
            notificationsSection
            defaultLadderSection
            snoozeSection
            remindersSection
            webhookSection
            aboutSection
        }
        .navigationTitle("Settings")
        .task {
            notificationStatus = await NotificationService.shared.checkPermissionStatus()
            defaultLadder = try? engine?.fetchDefaultLadder()
            if let saved = UserDefaults.standard.array(forKey: AppSettings.Key.snoozeDurations) as? [Int] {
                snoozeDurations = saved
            }
            remindersService.checkAuthorizationStatus()
            if remindersService.authorizationStatus == .fullAccess {
                remindersService.loadAvailableLists()
            }
            if let saved = UserDefaults.standard.array(forKey: AppSettings.Key.reminderListIdentifiers) as? [String] {
                selectedListIds = Set(saved)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            HStack {
                Text("Permission")
                Spacer()
                permissionBadge
            }

            if notificationStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Toggle("Time Sensitive Notifications", isOn: $timeSensitiveRequested)

            if timeSensitiveRequested {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Breaks through Focus modes. The user must also enable this in system Settings for BadgerMe.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Notifications")
        }
    }

    @ViewBuilder
    private var permissionBadge: some View {
        switch notificationStatus {
        case .authorized:
            Label("Enabled", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        case .denied:
            Label("Denied", systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
        case .provisional:
            Label("Provisional", systemImage: "circle.dashed")
                .font(.subheadline)
                .foregroundStyle(.orange)
        default:
            Label("Not Set", systemImage: "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ladders

    private var defaultLadderSection: some View {
        Section {
            NavigationLink {
                LadderListView()
            } label: {
                HStack {
                    Label("Escalation Ladders", systemImage: "ladder")
                    Spacer()
                    if let defaultLadder {
                        Text(defaultLadder.name)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Escalation Ladders")
        } footer: {
            Text("Manage your escalation ladders. The default ladder is used for new Badgers unless overridden.")
        }
    }

    // MARK: - Snooze

    private var snoozeSection: some View {
        Section {
            ForEach(snoozeDurations, id: \.self) { duration in
                HStack {
                    Text("\(duration) minutes")
                    Spacer()
                }
            }
            .onDelete(perform: removeSnooze)

            Menu {
                ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                    if !snoozeDurations.contains(minutes) {
                        Button("\(minutes) minutes") {
                            snoozeDurations.append(minutes)
                            snoozeDurations.sort()
                            saveSnooze()
                        }
                    }
                }
            } label: {
                Label("Add Duration", systemImage: "plus.circle")
            }
        } header: {
            Text("Snooze Options")
        } footer: {
            Text("These durations appear as notification action buttons.")
        }
    }

    private func removeSnooze(at offsets: IndexSet) {
        guard snoozeDurations.count - offsets.count >= 1 else { return }
        snoozeDurations.remove(atOffsets: offsets)
        saveSnooze()
    }

    private func saveSnooze() {
        UserDefaults.standard.set(snoozeDurations, forKey: AppSettings.Key.snoozeDurations)
        NotificationService.shared.registerCategories(snoozeDurations: snoozeDurations)
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            Toggle("Monitor Apple Reminders", isOn: $reminderPollingEnabled)
                .onChange(of: reminderPollingEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await remindersService.requestAccess()
                            if !granted {
                                reminderPollingEnabled = false
                            }
                        }
                    }
                }

            if reminderPollingEnabled {
                if remindersService.authorizationStatus == .fullAccess {
                    if remindersService.availableLists.isEmpty {
                        Text("No Reminder lists found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(remindersService.availableLists) { list in
                            Toggle(list.title, isOn: Binding(
                                get: { selectedListIds.contains(list.identifier) },
                                set: { isOn in
                                    if isOn {
                                        selectedListIds.insert(list.identifier)
                                    } else {
                                        selectedListIds.remove(list.identifier)
                                    }
                                    saveSelectedLists()
                                }
                            ))
                        }
                    }
                } else if remindersService.authorizationStatus == .denied {
                    Button("Grant Access in Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Checks for overdue reminders when the app opens and periodically in the background (~15-30 min).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Reminders Integration")
        }
    }

    private func saveSelectedLists() {
        UserDefaults.standard.set(Array(selectedListIds), forKey: AppSettings.Key.reminderListIdentifiers)
    }

    // MARK: - Webhook

    private var webhookSection: some View {
        Section {
            NavigationLink {
                WebhookSettingsView()
            } label: {
                HStack {
                    Label("Webhook Listener", systemImage: "network")
                    Spacer()
                    Text(webhookListenerEnabled ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Advanced")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
            }
            LabeledContent("Build") {
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
            }

            HStack {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                Text("No data collected. No accounts. No analytics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("About")
        }
    }
}
