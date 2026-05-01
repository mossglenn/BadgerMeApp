//
//  BadgerListView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct BadgerListView: View {
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @State private var showingNewBadger = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let engine {
                    if engine.activeBadgers.isEmpty && engine.snoozedBadgers.isEmpty {
                        emptyState
                    } else {
                        badgerList(engine: engine)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Active")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewBadger = true
                    } label: {
                        Label("New Badger", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewBadger) {
                NewBadgerView()
            }
            .navigationDestination(for: UUID.self) { badgerId in
                BadgerDetailView(badgerId: badgerId)
            }
        }
        .onChange(of: engine?.deepLinkBadgerId) { _, newId in
            if let id = newId {
                navigationPath = NavigationPath([id])
                engine?.deepLinkBadgerId = nil
            }
        }
    }

    // MARK: - Subviews

    private func badgerList(engine: BadgerEngine) -> some View {
        List {
            if !engine.activeBadgers.isEmpty {
                Section("Active") {
                    ForEach(engine.activeBadgers, id: \.id) { badger in
                        NavigationLink(value: badger.id) {
                            BadgerRowView(
                                badger: badger,
                                ladder: try? engine.resolvedLadder(for: badger)
                            )
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            engine.deleteBadger(engine.activeBadgers[index])
                        }
                    }
                }
            }

            if !engine.snoozedBadgers.isEmpty {
                Section("Snoozed") {
                    ForEach(engine.snoozedBadgers, id: \.id) { badger in
                        NavigationLink(value: badger.id) {
                            BadgerRowView(
                                badger: badger,
                                ladder: try? engine.resolvedLadder(for: badger)
                            )
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            engine.deleteBadger(engine.snoozedBadgers[index])
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Active Badgers", systemImage: "bell.slash")
        } description: {
            Text("Create a Badger to start getting escalating reminders.")
        } actions: {
            Button("New Badger") {
                showingNewBadger = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
