//
//  BadgerMeApp.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct BadgerMeApp: App {
    static let backgroundTaskIdentifier = "com.badgerme.reminders-refresh"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Badger.self,
            EscalationLadder.self,
            BadgerEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private let notificationService = NotificationService.shared
    @State private var badgerEngine: BadgerEngine?
    @State private var remindersService = RemindersService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppSettings.registerDefaults()
        notificationService.registerCategories()
        registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    _ = await notificationService.requestPermissions()
                }
                .onAppear {
                    if badgerEngine == nil {
                        let context = sharedModelContainer.mainContext
                        badgerEngine = BadgerEngine(modelContext: context)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        pollRemindersIfEnabled()
                    case .background:
                        scheduleBackgroundRefresh()
                    default:
                        break
                    }
                }
                .environment(badgerEngine)
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Foreground Polling

    private func pollRemindersIfEnabled() {
        guard UserDefaults.standard.bool(forKey: AppSettings.Key.reminderPollingEnabled),
              let engine = badgerEngine else { return }

        let listIds = UserDefaults.standard.stringArray(forKey: AppSettings.Key.reminderListIdentifiers) ?? []
        guard !listIds.isEmpty else { return }

        Task {
            await remindersService.pollAndCreateBadgers(engine: engine, listIdentifiers: listIds)
        }
    }

    // MARK: - Background Task

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBackgroundRefresh(task)
        }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        // Schedule the next refresh before doing work
        scheduleBackgroundRefresh()

        guard UserDefaults.standard.bool(forKey: AppSettings.Key.reminderPollingEnabled) else {
            task.setTaskCompleted(success: true)
            return
        }

        let listIds = UserDefaults.standard.stringArray(forKey: AppSettings.Key.reminderListIdentifiers) ?? []
        guard !listIds.isEmpty else {
            task.setTaskCompleted(success: true)
            return
        }

        // Background tasks need their own ModelContext from the container
        let container = sharedModelContainer
        let backgroundReminders = RemindersService()

        let workTask = Task { @MainActor in
            let context = ModelContext(container)
            let engine = BadgerEngine(modelContext: context)
            await backgroundReminders.pollAndCreateBadgers(engine: engine, listIdentifiers: listIds)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleBackgroundRefresh() {
        guard UserDefaults.standard.bool(forKey: AppSettings.Key.reminderPollingEnabled) else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
}
