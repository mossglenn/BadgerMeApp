//
//  ContentView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

enum AppTab: Hashable {
    case active, history, settings
}

struct ContentView: View {
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @State private var selectedTab: AppTab = .active

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Active", systemImage: "bell.badge", value: .active) {
                BadgerListView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: .history) {
                NavigationStack {
                    HistoryView()
                }
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onChange(of: engine?.deepLinkBadgerId) { _, newId in
            if newId != nil {
                selectedTab = .active
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { engine?.presentedError != nil },
                set: { if !$0 { engine?.presentedError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = engine?.presentedError {
                Text(error)
            }
        }
    }
}

#Preview {
    ContentView()
}
