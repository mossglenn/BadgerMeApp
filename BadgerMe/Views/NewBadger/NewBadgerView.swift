//
//  NewBadgerView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct NewBadgerView: View {
    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var startsAt = Date()
    @State private var startNow = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                        .font(.headline)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("When to start badgering") {
                    Toggle("Start immediately", isOn: $startNow)

                    if !startNow {
                        DatePicker(
                            "Start time",
                            selection: $startsAt,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "ladder")
                        Text("Uses default escalation ladder")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
            }
            .navigationTitle("New Badger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createBadger()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createBadger() {
        let effectiveStart = startNow ? Date() : startsAt
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        Task {
            await engine?.createBadger(
                title: title.trimmingCharacters(in: .whitespaces),
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                startsAt: effectiveStart
            )
            dismiss()
        }
    }
}

#Preview {
    NewBadgerView()
}
