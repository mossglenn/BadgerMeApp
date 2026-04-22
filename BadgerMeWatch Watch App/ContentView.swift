//
//  ContentView.swift
//  BadgerMeWatch Watch App
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    @State private var sessionManager = WatchSessionManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if sessionManager.activeBadgers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No Active Badgers")
                            .font(.headline)
                        Text("Create Badgers on your iPhone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(sessionManager.activeBadgers) { badger in
                        NavigationLink(value: badger.id) {
                            WatchBadgerRow(badger: badger)
                        }
                    }
                    .navigationDestination(for: UUID.self) { badgerId in
                        if let badger = sessionManager.activeBadgers.first(where: { $0.id == badgerId }) {
                            WatchBadgerDetailView(badger: badger)
                        }
                    }
                }
            }
            .navigationTitle("BadgerMe")
        }
    }
}

// MARK: - Badger Row

struct WatchBadgerRow: View {
    let badger: WatchBadger

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: badger.state == "snoozed" ? "moon.zzz.fill" : "bell.badge.fill")
                    .foregroundStyle(badger.state == "snoozed" ? .orange : .red)
                    .font(.caption)
                Text(badger.title)
                    .font(.headline)
                    .lineLimit(2)
            }
            Text("Level \(badger.currentLevel + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Badger Detail with Actions

struct WatchBadgerDetailView: View {
    let badger: WatchBadger
    @State private var sessionManager = WatchSessionManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(badger.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Level \(badger.currentLevel + 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Button {
                    sessionManager.sendDone(badgerId: badger.id)
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                Button {
                    sessionManager.sendSnooze(badgerId: badger.id, minutes: 15)
                    dismiss()
                } label: {
                    Label("Snooze 15m", systemImage: "moon.zzz")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    sessionManager.sendDismiss(badgerId: badger.id)
                    dismiss()
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Badger")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}
