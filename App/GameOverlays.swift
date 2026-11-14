import ColorFlowCore
import SwiftUI

private let ink = Color(red: 0.10, green: 0.19, blue: 0.30)
private let cream = Color(red: 1, green: 0.96, blue: 0.84)
private let river = Color(red: 0.05, green: 0.68, blue: 0.72)

struct CartoonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color(red: 1, green: 0.79, blue: 0.31), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ink, lineWidth: 2))
            .compositingGroup()
            .shadow(color: ink.opacity(0.25), radius: 0, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SettingsEntryLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
                .frame(width: 32, height: 32)
                .background(ink, in: Circle())
            Text(title)
        }
    }
}

struct CartoonPanel<Content: View>: View {
    let title: String
    let icon: String
    var close: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(icon == "lightbulb.fill" ? Color.yellow : Color.orange)
                    .padding(9)
                    .frame(width: 42, height: 42)
                    .background(ink, in: Circle())
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if let close {
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(ink)
                            .frame(width: 48, height: 48)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("close-overlay")
                }
            }
            content()
        }
        .padding(20)
        .foregroundStyle(ink)
        .background(cream, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(river, lineWidth: 3))
        .compositingGroup()
        .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        .frame(maxWidth: 440)
        .environment(\.colorScheme, .light)
    }
}

struct StatsTable: View {
    let statistics: GameStatistics

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 4) {
                heading("Difficulty", alignment: .leading)
                heading("Win %")
                heading("Avg. win\ntime")
            }
            .padding(.horizontal, 10)
            ForEach(Difficulty.allCases, id: \.self) { difficulty in
                let stats = statistics[difficulty]
                let percentage = stats.victoryPercentage.map { "\(Int($0.rounded()))%" } ?? "—"
                let duration = formattedDuration(stats.averageWinningSeconds)
                HStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(difficultyColor(difficulty)).frame(width: 8, height: 8)
                        Text(difficulty.rawValue.capitalized)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(percentage).frame(maxWidth: .infinity)
                    Text(duration).frame(maxWidth: .infinity)
                }
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 18)
                .background(Color(red: 1, green: 0.99, blue: 0.96), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(ink, lineWidth: 2))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(difficulty.rawValue.capitalized). Win percentage: \(percentage). Average win time: \(duration).")
                .accessibilityIdentifier("stats-\(difficulty.rawValue)")
            }
        }
        .foregroundStyle(ink)
    }

    private func heading(_ title: String, alignment: Alignment = .center) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func formattedDuration(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "—" }
        if seconds <= 60 { return "\(Int(seconds.rounded())) sec" }
        return String(format: "%.1f min", locale: Locale(identifier: "en_US_POSIX"), seconds / 60)
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy: river
        case .medium: Color(red: 0.91, green: 0.65, blue: 0.13)
        case .hard: Color(red: 0.62, green: 0.42, blue: 0.78)
        }
    }
}

struct HintRiverView: View {
    let presentation: HintPresentation

    var body: some View {
        switch presentation {
        case .idle, .searching:
            VStack(spacing: 16) {
                ProgressView().tint(ink)
                    .accessibilityLabel("Finding a winning path")
                    .accessibilityIdentifier("hint-loading")
                Text("Finding a winning path…")
                Text("This can take up to 10 seconds.").font(.callout)
            }
            .frame(maxWidth: .infinity, minHeight: 160)

        case .finished(let result):
            switch result {
            case .steps(let steps) where !steps.isEmpty:
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(steps) { step in HintRiverRow(step: step) }
                    }
                    .padding(.vertical, 8)
                    .background(alignment: .leading) {
                        Image("HintRiver").resizable().frame(width: 80).offset(x: -13).accessibilityHidden(true)
                    }
                }
                .scrollIndicators(.visible)
                .accessibilityIdentifier("hint-route")
            case .steps:
                Text("You have already cleared this level!")
            case .unwinnable:
                Text("No winning path remains from here. Retry the level for a fresh start.")
                    .accessibilityIdentifier("hint-unwinnable")
            case .inconclusive:
                Text("The search could not finish within 10 seconds. A winning path may still exist. Try Hint again after a move.")
                    .accessibilityIdentifier("hint-inconclusive")
            }
        }
    }
}

private struct HintRiverRow: View {
    let step: HintStep

    var body: some View {
        HStack(spacing: 10) {
            Text("\(step.id)")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .frame(width: 54, height: 48)
                .background {
                    Image("HintStone").resizable().frame(width: 54, height: 54)
                }
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(step.instruction)
                    .font(.system(.body, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 3) {
                    ForEach(step.controls.indices, id: \.self) { index in
                        VStack(spacing: 0) {
                            PaintArtwork(color: step.controls[index]?.color, quantity: step.controls[index]?.paintUnits,
                                         tin: step.isRetrieval)
                                .frame(height: 48)
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .background(index == step.targetIndex ? Color.yellow.opacity(0.35) : .clear,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .overlay {
                            if index == step.targetIndex {
                                RoundedRectangle(cornerRadius: 10).strokeBorder(river, lineWidth: 3)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if index == step.targetIndex {
                                Image(systemName: "hand.tap.fill").foregroundStyle(ink)
                            }
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(river.opacity(0.45), lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.id). \(step.instruction). \(step.target.paintUnits) paint units.")
        .accessibilityIdentifier("hint-step-\(step.id)")
    }
}
