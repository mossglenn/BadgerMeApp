//
//  BadgerMeApp.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI
import SwiftData

@main
struct BadgerMeApp: App {
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

    init() {
        AppSettings.registerDefaults()
        notificationService.registerCategories()
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
                .environment(badgerEngine)
        }
        .modelContainer(sharedModelContainer)
    }
}
