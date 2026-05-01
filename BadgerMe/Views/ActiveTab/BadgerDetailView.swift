//
//  BadgerDetailView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI
import SwiftData

struct BadgerDetailView: View {
    let badgerId: UUID

    @Environment(BadgerEngine.self) private var engine: BadgerEngine?
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showingEdit = false

    private var badger: Badger? {
        engine?.activeBadgers.first { $0.id == badgerId }
            ?? engine?.snoozedBadgers.first { $0.id == badgerId }
            ?? engine?.recentHistory.first { $0.id == badgerId }
    }

    var body: some View {
        Group {
            if let badger {
                detailContent(badger)
            } else {
                ContentUnavailableView("Badger Not Found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(badger?.title ?? "Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let badger, badger.state == .active || badger.state == .snoozed {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingEdit = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let badger {
                BadgerEditView(badger: badger)
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ badger: Badger) -> some View {
        List {
            // Status section
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        statusIcon(for: badger.state)
                        Text(badger.state.rawValue.capitalized)
                    }
                }

                LabeledContent("Created") {
                    Text(badger.createdAt, format: .dateTime)
                }

                LabeledContent("Started") {
                    Text(badger.startsAt, format: .dateTime)
                }

                if let ladder = try? engine?.resolvedLadder(for: badger) {
                    LabeledContent("Level") {
                        LevelIndicatorView(
                            level: badger.currentLevel,
                            totalLevels: ladder.levels.count
                        )
                    }
                }

                if badger.snoozeCount > 0 {
                    LabeledContent("Snooze Count") {
                        Text("\(badger.snoozeCount)")
                    }
                }

                LabeledContent("Source") {
                    Text(badger.sourceType.rawValue.capitalized)
                }
            }

            // Notes
            if let notes = badger.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.body)
                }
            }

            // Event timeline
            if let engine {
                let events = engine.fetchEvents(for: badger.id)
                if !events.isEmpty {
                    Section("Timeline") {
                        ForEach(events, id: \.id) { event in
                            HStack {
                                eventIcon(for: event.eventType)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.eventType.rawValue.capitalized)
                                        .font(.subheadline)
                                    if let notes = event.notes {
                                        Text(notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(event.timestamp, format: .dateTime.hour().minute().second())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Actions (only for active/snoozed Badgers)
            if badger.state == .active || badger.state == .snoozed {
                Section {
                    Button {
                        Task { await engine?.markDone(badger) }
                        dismiss()
                    } label: {
                        Label("Mark Done", systemImage: "checkmark.circle")
                    }
                    .tint(.green)

                    Button {
                        Task { await engine?.snooze(badger, durationMinutes: 15) }
                        dismiss()
                    } label: {
                        Label("Snooze 15 Minutes", systemImage: "moon.zzz")
                    }

                    Button(role: .destructive) {
                        engine?.dismiss(badger)
                        dismiss()
                    } label: {
                        Label("Dismiss", systemImage: "xmark.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Badger", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this Badger?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                engine?.deleteBadger(badger)
                dismiss()
            }
        } message: {
            Text("This will cancel all pending notifications for this Badger.")
        }
    }

    // MARK: - Helpers

    private func statusIcon(for state: BadgerState) -> some View {
        Group {
            switch state {
            case .active:
                Image(systemName: "bell.badge.fill").foregroundStyle(.red)
            case .snoozed:
                Image(systemName: "moon.zzz.fill").foregroundStyle(.orange)
            case .completed:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .dismissed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            case .abandoned:
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.secondary)
            }
        }
    }

    private func eventIcon(for type: BadgerEventType) -> some View {
        Group {
            switch type {
            case .created:
                Image(systemName: "plus.circle").foregroundStyle(.blue)
            case .levelFired:
                Image(systemName: "bell.fill").foregroundStyle(.orange)
            case .snoozed:
                Image(systemName: "moon.zzz").foregroundStyle(.yellow)
            case .completed:
                Image(systemName: "checkmark.circle").foregroundStyle(.green)
            case .dismissed:
                Image(systemName: "xmark.circle").foregroundStyle(.secondary)
            case .abandoned:
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.red)
            case .escalated:
                Image(systemName: "arrow.up.circle").foregroundStyle(.orange)
            }
        }
    }
}
