//
//  LadderEditorView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

/// Full editor for an escalation ladder: reorderable level cards,
/// nuclear option picker, and snooze configuration.
struct LadderEditorView: View {
    @Bindable var ladder: EscalationLadder
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            // Ladder name
            Section {
                TextField("Ladder Name", text: $ladder.name)
            }

            // Levels
            Section {
                ForEach(sortedLevelIndices, id: \.self) { index in
                    NavigationLink {
                        LevelEditorView(level: $ladder.levels[index])
                    } label: {
                        LevelCardView(level: ladder.levels[index], totalLevels: ladder.levels.count)
                    }
                }
                .onMove(perform: moveLevel)
                .onDelete(perform: deleteLevel)

                Button {
                    addLevel()
                } label: {
                    Label("Add Level", systemImage: "plus.circle")
                }
            } header: {
                Text("Escalation Levels")
            } footer: {
                Text("Levels fire in order. Drag to reorder. Each level waits its duration before the next one fires.")
            }

            // Snooze configuration
            Section("Snooze Behavior") {
                Stepper(
                    "Max snoozes: \(ladder.maxSnoozeCount)",
                    value: $ladder.maxSnoozeCount,
                    in: 1...10
                )

                Picker("Restart from level", selection: $ladder.snoozeRestartLevel) {
                    ForEach(0..<max(ladder.levels.count, 1), id: \.self) { index in
                        Text("Level \(index + 1)").tag(index)
                    }
                }

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("After max snoozes, the Badger restarts one level higher than configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Nuclear option
            Section {
                Picker("When all levels exhausted", selection: $ladder.nuclearOption) {
                    ForEach(NuclearOption.allCases, id: \.self) { option in
                        Text(nuclearOptionLabel(option)).tag(option)
                    }
                }
            } header: {
                Text("Nuclear Option")
            } footer: {
                Text(nuclearOptionDescription(ladder.nuclearOption))
            }
        }
        .navigationTitle(ladder.name.isEmpty ? "Edit Ladder" : ladder.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Indices into ladder.levels sorted by their order property.
    private var sortedLevelIndices: [Int] {
        ladder.levels.indices.sorted { ladder.levels[$0].order < ladder.levels[$1].order }
    }

    // MARK: - Level Management

    private func addLevel() {
        let newOrder = ladder.levels.count
        let newLevel = EscalationLevel(
            order: newOrder,
            waitDurationSeconds: 600, // 10 minutes default
            actions: [
                EscalationAction(
                    type: .notificationBanner,
                    config: ActionConfig(interruptionLevel: .active)
                ),
                EscalationAction(
                    type: .sound,
                    config: ActionConfig(soundVolume: 0.7)
                ),
            ]
        )
        ladder.levels.append(newLevel)
    }

    private func moveLevel(from source: IndexSet, to destination: Int) {
        var sorted = ladder.levels.sorted { $0.order < $1.order }
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, _) in sorted.enumerated() {
            sorted[index].order = index
        }
        ladder.levels = sorted
    }

    private func deleteLevel(at offsets: IndexSet) {
        var sorted = ladder.levels.sorted { $0.order < $1.order }
        sorted.remove(atOffsets: offsets)
        for (index, _) in sorted.enumerated() {
            sorted[index].order = index
        }
        ladder.levels = sorted

        // Keep snoozeRestartLevel in bounds
        if ladder.snoozeRestartLevel >= ladder.levels.count {
            ladder.snoozeRestartLevel = max(0, ladder.levels.count - 1)
        }
    }

    // MARK: - Nuclear Option Labels

    private func nuclearOptionLabel(_ option: NuclearOption) -> String {
        switch option {
        case .repeatForever: "Repeat forever"
        case .giveUp: "Give up"
        case .notifyContact: "Notify contact (V2)"
        }
    }

    private func nuclearOptionDescription(_ option: NuclearOption) -> String {
        switch option {
        case .repeatForever:
            "Keeps repeating the final level at its configured interval until you respond."
        case .giveUp:
            "Stops badgering and marks the task as abandoned."
        case .notifyContact:
            "Sends a message to a nominated contact. Coming in a future update."
        }
    }
}

// MARK: - Level Card

/// Compact card showing a level's order, wait time, and action chips.
struct LevelCardView: View {
    let level: EscalationLevel
    let totalLevels: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LevelIndicatorView(level: level.order, totalLevels: totalLevels)

                Text("Wait \(level.waitDurationSeconds / 60) min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Action chips
            HStack(spacing: 6) {
                ForEach(level.actions, id: \.type) { action in
                    actionChip(action)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func actionChip(_ action: EscalationAction) -> some View {
        HStack(spacing: 3) {
            actionIcon(action.type)
            Text(actionLabel(action.type))
        }
        .font(.caption2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.fill.tertiary, in: Capsule())
    }

    private func actionIcon(_ type: ActionType) -> Image {
        switch type {
        case .sound: Image(systemName: "speaker.wave.2")
        case .speakText: Image(systemName: "mouth")
        case .torchFlash: Image(systemName: "flashlight.on.fill")
        case .notificationBanner: Image(systemName: "bell")
        }
    }

    private func actionLabel(_ type: ActionType) -> String {
        switch type {
        case .sound: "Sound"
        case .speakText: "Speak"
        case .torchFlash: "Torch"
        case .notificationBanner: "Banner"
        }
    }
}
