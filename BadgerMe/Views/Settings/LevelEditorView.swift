//
//  LevelEditorView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

/// Editor for a single escalation level's actions and wait duration.
struct LevelEditorView: View {
    @Binding var level: EscalationLevel
    @Environment(\.dismiss) private var dismiss

    // Local editing state
    @State private var waitMinutes: Int
    @State private var hasSound: Bool
    @State private var soundVolume: Float
    @State private var hasSpeakText: Bool
    @State private var speechVolume: Float
    @State private var hasTorchFlash: Bool
    @State private var torchDuration: Double
    @State private var isTimeSensitive: Bool

    init(level: Binding<EscalationLevel>) {
        self._level = level
        let l = level.wrappedValue

        _waitMinutes = State(initialValue: l.waitDurationSeconds / 60)

        let soundAction = l.actions.first { $0.type == .sound }
        _hasSound = State(initialValue: soundAction != nil)
        _soundVolume = State(initialValue: soundAction?.config.soundVolume ?? 0.7)

        let speakAction = l.actions.first { $0.type == .speakText }
        _hasSpeakText = State(initialValue: speakAction != nil)
        _speechVolume = State(initialValue: speakAction?.config.speechVolume ?? 1.0)

        let torchAction = l.actions.first { $0.type == .torchFlash }
        _hasTorchFlash = State(initialValue: torchAction != nil)
        _torchDuration = State(initialValue: torchAction?.config.torchDuration ?? 1.0)

        let interruptionConfig = l.actions.first { $0.config.interruptionLevel != nil }
        _isTimeSensitive = State(initialValue: interruptionConfig?.config.interruptionLevel == .timeSensitive)
    }

    var body: some View {
        Form {
            Section("Wait Duration") {
                Stepper(
                    "\(waitMinutes) minute\(waitMinutes == 1 ? "" : "s")",
                    value: $waitMinutes,
                    in: 1...120
                )
            }

            Section("Notification") {
                Toggle("Time Sensitive", isOn: $isTimeSensitive)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Breaks through Focus modes when enabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sound") {
                Toggle("Play Sound", isOn: $hasSound)

                if hasSound {
                    VStack(alignment: .leading) {
                        Text("Volume: \(Int(soundVolume * 100))%")
                            .font(.subheadline)
                        Slider(value: $soundVolume, in: 0.1...1.0, step: 0.1)
                    }
                }
            }

            Section("Speak Text") {
                Toggle("Speak Task Title", isOn: $hasSpeakText)

                if hasSpeakText {
                    VStack(alignment: .leading) {
                        Text("Volume: \(Int(speechVolume * 100))%")
                            .font(.subheadline)
                        Slider(value: $speechVolume, in: 0.1...1.0, step: 0.1)
                    }

                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Speech is pre-rendered as audio and plays via the notification sound")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Torch Flash") {
                Toggle("Flash Torch", isOn: $hasTorchFlash)

                if hasTorchFlash {
                    VStack(alignment: .leading) {
                        Text("Duration: \(String(format: "%.1f", torchDuration))s")
                            .font(.subheadline)
                        Slider(value: $torchDuration, in: 0.5...5.0, step: 0.5)
                    }
                }
            }
        }
        .navigationTitle("Level \(level.order + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    applyChanges()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func applyChanges() {
        level.waitDurationSeconds = waitMinutes * 60

        var actions: [EscalationAction] = []

        // Notification banner is always present
        actions.append(EscalationAction(
            type: .notificationBanner,
            config: ActionConfig(
                interruptionLevel: isTimeSensitive ? .timeSensitive : .active
            )
        ))

        if hasSound {
            actions.append(EscalationAction(
                type: .sound,
                config: ActionConfig(soundVolume: soundVolume)
            ))
        }

        if hasSpeakText {
            actions.append(EscalationAction(
                type: .speakText,
                config: ActionConfig(speechVolume: speechVolume)
            ))
        }

        if hasTorchFlash {
            actions.append(EscalationAction(
                type: .torchFlash,
                config: ActionConfig(torchDuration: torchDuration)
            ))
        }

        level.actions = actions
    }
}
