//
//  HistoryView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct HistoryView: View {
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?

    var body: some View {
        Group {
            if let engine {
                if engine.recentHistory.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed and dismissed Badgers will appear here.")
                    )
                } else {
                    List {
                        ForEach(engine.recentHistory, id: \.id) { badger in
                            NavigationLink(value: badger.id) {
                                BadgerRowView(badger: badger, ladder: nil)
                            }
                        }
                    }
                    .navigationDestination(for: UUID.self) { badgerId in
                        BadgerDetailView(badgerId: badgerId)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("History")
    }
}
