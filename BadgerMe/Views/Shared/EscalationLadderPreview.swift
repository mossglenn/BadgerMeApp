//
//  EscalationLadderPreview.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

/// A compact visual summary of an escalation ladder, showing levels as
/// connected colored dots with time labels.
struct EscalationLadderPreview: View {
    let ladder: EscalationLadder

    var body: some View {
        let levels = ladder.levels.sorted { $0.order < $1.order }
        VStack(alignment: .leading, spacing: 8) {
            Text(ladder.name)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 0) {
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    // Level dot
                    VStack(spacing: 2) {
                        Circle()
                            .fill(levelColor(index: index, total: levels.count))
                            .frame(width: 12, height: 12)
                        Text("\(level.waitDurationSeconds / 60)m")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Connector line (except after last level)
                    if index < levels.count - 1 {
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 14) // align with circle center
                    }
                }

                // Nuclear indicator
                VStack(spacing: 2) {
                    Image(systemName: nuclearIcon)
                        .font(.caption2)
                        .foregroundStyle(nuclearColor)
                    Text(nuclearLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }
        }
    }

    private func levelColor(index: Int, total: Int) -> Color {
        guard total > 1 else { return .blue }
        let fraction = Double(index) / Double(total - 1)
        switch fraction {
        case ..<0.34: return .blue
        case ..<0.67: return .orange
        default: return .red
        }
    }

    private var nuclearIcon: String {
        switch ladder.nuclearOption {
        case .repeatForever: "repeat"
        case .giveUp: "flag"
        case .notifyContact: "message"
        }
    }

    private var nuclearColor: Color {
        switch ladder.nuclearOption {
        case .repeatForever: .red
        case .giveUp: .secondary
        case .notifyContact: .blue
        }
    }

    private var nuclearLabel: String {
        switch ladder.nuclearOption {
        case .repeatForever: "Loop"
        case .giveUp: "Stop"
        case .notifyContact: "Msg"
        }
    }
}
