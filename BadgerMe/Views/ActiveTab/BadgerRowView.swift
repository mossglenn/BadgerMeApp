//
//  BadgerRowView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

struct BadgerRowView: View {
    let badger: Badger
    let ladder: EscalationLadder?

    var body: some View {
        HStack(spacing: 12) {
            // State icon
            stateIcon
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                // Title row with level indicator
                HStack {
                    Text(badger.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    if badger.state == .active, let ladder {
                        LevelIndicatorView(
                            level: badger.currentLevel,
                            totalLevels: ladder.levels.count
                        )
                    }
                }

                // Subtitle row
                HStack {
                    subtitleText
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if badger.state == .active, let ladder,
                       let nextDate = badger.nextEscalationAt(using: ladder),
                       nextDate > Date() {
                        CountdownView(targetDate: nextDate, label: "Next:")
                    }
                }

                // Snooze count if snoozed before
                if badger.snoozeCount > 0 {
                    Text("Snoozed \(badger.snoozeCount)×")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var stateIcon: some View {
        switch badger.state {
        case .active:
            Image(systemName: "bell.badge.fill")
                .foregroundStyle(.red)
        case .snoozed:
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .dismissed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        case .abandoned:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private var subtitleText: some View {
        Group {
            switch badger.state {
            case .active:
                Text("Started \(badger.startsAt, format: .relative(presentation: .named))")
            case .snoozed:
                Text("Snoozed — will resume \(badger.startsAt, format: .relative(presentation: .named))")
            case .completed:
                Text("Done \(badger.acknowledgedAt ?? badger.createdAt, format: .relative(presentation: .named))")
            case .dismissed:
                Text("Dismissed \(badger.acknowledgedAt ?? badger.createdAt, format: .relative(presentation: .named))")
            case .abandoned:
                Text("Abandoned \(badger.acknowledgedAt ?? badger.createdAt, format: .relative(presentation: .named))")
            }
        }
    }
}
