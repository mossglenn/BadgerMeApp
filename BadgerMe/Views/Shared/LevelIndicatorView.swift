//
//  LevelIndicatorView.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import SwiftUI

/// Displays the current escalation level as a colored badge.
/// Color temperature rises with level: cool → warm → hot.
struct LevelIndicatorView: View {
    let level: Int
    let totalLevels: Int

    var body: some View {
        Text("L\(level + 1)")
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: level), in: Capsule())
    }

    private func color(for level: Int) -> Color {
        guard totalLevels > 1 else { return .blue }
        let fraction = Double(level) / Double(totalLevels - 1)
        switch fraction {
        case ..<0.34:
            return .blue
        case ..<0.67:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    HStack {
        LevelIndicatorView(level: 0, totalLevels: 3)
        LevelIndicatorView(level: 1, totalLevels: 3)
        LevelIndicatorView(level: 2, totalLevels: 3)
    }
}
