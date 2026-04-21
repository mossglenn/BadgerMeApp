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

    var body: some View {
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
        .navigationDestination(for: UUID.self) { badgerId in
            BadgerDetailView(badgerId: badgerId)
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
