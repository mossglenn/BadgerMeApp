//
//  BadgerEditView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/30/26.
//

import SwiftUI
import SwiftData

struct BadgerEditView: View {
    let badger: Badger
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EscalationLadder.name) private var ladders: [EscalationLadder]

    @State private var title: String
    @State private var notes: String
    @State private var selectedLadderId: UUID?

    init(badger: Badger) {
        self.badger = badger
        _title = State(initialValue: badger.title)
        _notes = State(initialValue: badger.notes ?? "")
        _selectedLadderId = State(initialValue: badger.customLadder?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Escalation Ladder") {
                    Picker("Ladder", selection: $selectedLadderId) {
                        Text("Default").tag(nil as UUID?)
                        ForEach(ladders) { ladder in
                            Text(ladder.name).tag(ladder.id as UUID?)
                        }
                    }
                }
            }
            .navigationTitle("Edit Badger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let customLadder = ladders.first { $0.id == selectedLadderId }

        Task {
            await engine?.updateBadger(
                badger,
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                customLadder: customLadder
            )
            dismiss()
        }
    }
}
