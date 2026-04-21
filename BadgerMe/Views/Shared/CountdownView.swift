//
//  CountdownView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

/// Displays a live countdown to a target date using a monospaced font.
struct CountdownView: View {
    let targetDate: Date
    let label: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(targetDate.timeIntervalSince(context.date), 0)
            HStack(spacing: 4) {
                Text(label)
                    .foregroundStyle(.secondary)
                Text(formatted(remaining))
                    .monospacedDigit()
                    .foregroundStyle(remaining < 60 ? .red : .primary)
            }
            .font(.caption)
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    CountdownView(
        targetDate: Date().addingTimeInterval(325),
        label: "Next:"
    )
}
