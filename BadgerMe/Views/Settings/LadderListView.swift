//
//  LadderListView.swift
//  BadgerMe
//

import SwiftUI
import SwiftData

struct LadderListView: View {
    @Query(sort: \EscalationLadder.name) private var ladders: [EscalationLadder]
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppSettings.Key.defaultLadderId) private var defaultLadderIdString: String = ""

    private var defaultLadderId: UUID? {
        UUID(uuidString: defaultLadderIdString)
    }

    var body: some View {
        List {
            ForEach(ladders) { ladder in
                NavigationLink {
                    LadderEditorView(ladder: ladder)
                } label: {
                    HStack {
                        EscalationLadderPreview(ladder: ladder)
                        Spacer()
                        if ladder.id == defaultLadderId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .contextMenu {
                    if ladder.id != defaultLadderId {
                        Button {
                            setDefault(ladder)
                        } label: {
                            Label("Set as Default", systemImage: "checkmark.circle")
                        }
                    }

                    Button {
                        duplicateLadder(ladder)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    if ladder.id != defaultLadderId {
                        Button(role: .destructive) {
                            deleteLadder(ladder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onDelete(perform: deleteAtOffsets)
        }
        .navigationTitle("Escalation Ladders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addLadder()
                } label: {
                    Label("Add Ladder", systemImage: "plus")
                }
            }
        }
    }

    // MARK: - Actions

    private func addLadder() {
        let ladder = BadgerEngine.createFactoryDefaultLadder()
        ladder.name = "New Ladder"
        modelContext.insert(ladder)
        try? modelContext.save()
    }

    private func setDefault(_ ladder: EscalationLadder) {
        defaultLadderIdString = ladder.id.uuidString
    }

    private func duplicateLadder(_ source: EscalationLadder) {
        let copy = EscalationLadder(
            name: "\(source.name) Copy",
            levels: source.levels,
            nuclearOption: source.nuclearOption,
            maxSnoozeCount: source.maxSnoozeCount,
            snoozeRestartLevel: source.snoozeRestartLevel
        )
        modelContext.insert(copy)
        try? modelContext.save()
    }

    private func deleteLadder(_ ladder: EscalationLadder) {
        guard ladder.id != defaultLadderId else { return }
        modelContext.delete(ladder)
        try? modelContext.save()
    }

    private func deleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            let ladder = ladders[index]
            guard ladder.id != defaultLadderId else { continue }
            modelContext.delete(ladder)
        }
        try? modelContext.save()
    }
}
