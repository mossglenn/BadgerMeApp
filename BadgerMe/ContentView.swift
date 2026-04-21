//
//  ContentView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Active", systemImage: "bell.badge") {
                NavigationStack {
                    BadgerListView()
                }
            }

            Tab("History", systemImage: "clock.arrow.circlepath") {
                NavigationStack {
                    HistoryView()
                }
            }

            Tab("Settings", systemImage: "gear") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
