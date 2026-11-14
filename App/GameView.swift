import ColorFlowCore
import SwiftUI

struct GameView: View {
    @Bindable var model: GameModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRestart = false
    @State private var confirmClearStats = false
    @State private var panel: GamePanel?
    private var hasOverlay: Bool { panel != nil || (!model.busy && model.outcome != .playing) }
    private var gameplayActive: Bool {
        scenePhase == .active && !hasOverlay && !confirmRestart && model.saveError == nil
    }
    private var reduceMotionEnabled: Bool {
        reducedMotion || (ProcessInfo.processInfo.environment["COLOR_FLOW_UI_TEST"] == "1" &&
                          ProcessInfo.processInfo.environment["COLOR_FLOW_REDUCE_MOTION"] == "1")
    }
    private let background = Color(red: 0.067, green: 0.094, blue: 0.153)

    var body: some View {
        GeometryReader { geometry in
            let gridSize = min(geometry.size.width - 8, geometry.size.height - 280, 440)
            ZStack {
                VStack(spacing: 2) {
                    header.frame(height: 56)
                    board(size: gridSize)
                    slots.frame(height: 84)
                    queues.frame(height: 92)
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(!hasOverlay)
                .accessibilityHidden(hasOverlay)
                if hasOverlay {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    modal(maxHeight: geometry.size.height - 32)
                        .padding(.horizontal, 20)
                        .accessibilityAddTraits(.isModal)
                }
            }
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Restart this level?", isPresented: $confirmRestart) {
            Button("Restart Level", role: .destructive) { model.restart() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Clear all stats?", isPresented: $confirmClearStats) {
            Button("Clear stats", role: .destructive) { model.clearStatistics() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your recorded statistics will be permanently deleted.")
        }
        .alert("Progress Not Saved", isPresented: Binding(get: { model.saveError != nil }, set: { if !$0 { model.saveError = nil } })) {
            Button("Try Again") { model.save() }
        } message: { Text(model.saveError ?? "") }
        .onAppear { model.setGameplayActive(gameplayActive) }
        .onDisappear { model.setGameplayActive(false) }
        .onChange(of: gameplayActive) { _, active in model.setGameplayActive(active) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.finishAnimation()
                model.cancelHint()
                panel = nil
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Text("\(model.level.id)")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.10, green: 0.19, blue: 0.30))
                    .frame(minWidth: 49, minHeight: 49)
                    .background(Color(red: 1, green: 0.79, blue: 0.31), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(red: 1, green: 0.89, blue: 0.60), lineWidth: 2))
                    .shadow(color: Color.orange.opacity(0.5), radius: 0, y: 3)
                    .rotationEffect(.degrees(-4))
                    .accessibilityLabel("Level \(model.level.id) of \(model.levels.count)")
                    .accessibilityIdentifier("level-number")
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("Level").font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("of \(model.levels.count)").font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
                    HStack(spacing: 6) {
                        Circle().fill(.cyan).frame(width: 6, height: 6).accessibilityHidden(true)
                        Text(model.level.difficulty.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.cyan)
                            .accessibilityIdentifier("level-difficulty")
                    }
                }
            }
            .padding(.leading, 5)
            Spacer()
            Button { panel = .settings } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .frame(width: 44, height: 44)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.cyan.opacity(0.65), lineWidth: 2))
                    .contentShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Game settings")
            .accessibilityIdentifier("settings")
            .disabled(model.busy || model.outcome != .playing)
        }
    }

    private let boardHeadroom: CGFloat = 36
    private let blockGap: CGFloat = 2

    private func board(size: CGFloat) -> some View {
        let cellSize = (size - CGFloat(model.level.width - 1) * blockGap) / CGFloat(model.level.width)
        return ZStack(alignment: .topLeading) {
            ForEach(model.engine.remainingBoxes(state: model.presentationState)) { box in
                let row = model.engine.boxState(id: box.id, state: model.presentationState).row
                block(box, cellSize: cellSize)
                    .offset(x: CGFloat(box.column) * (cellSize + blockGap),
                            y: boardHeadroom + CGFloat(row) * (cellSize + blockGap))
            }
            if let pour = model.pour, let entry = model.pourDestination, !reduceMotionEnabled {
                pourOverlay(pour, entry: entry, cellSize: cellSize)
            }
        }
        .frame(width: size, height: size + boardHeadroom, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Puzzle grid")
        .accessibilityIdentifier("board")
        .accessibilityValue(model.busy ? "Pouring" : "Ready")
    }

    private func block(_ box: BoxDefinition, cellSize: CGFloat) -> some View {
        let width = CGFloat(box.width) * cellSize + CGFloat(box.width - 1) * blockGap
        let height = CGFloat(box.height) * cellSize + CGFloat(box.height - 1) * blockGap
        let color = box.color.displayColor
        let fraction = model.fillUnits(for: box) / Double(box.capacity)
        return RoundedRectangle(cornerRadius: 4)
            .fill(color.opacity(0.16))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(color)
                    .frame(height: max(0, height - 4) * fraction)
                    .padding(2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(color, lineWidth: 2)
            }
            .frame(width: width, height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.busy ? "Pouring" : model.boxSummary(box))
            .accessibilityIdentifier("box-\(box.id)")
    }

    private func pourOverlay(_ pour: PourPresentation, entry: Cell, cellSize: CGFloat) -> some View {
        let centerX = CGFloat(entry.column) * (cellSize + blockGap) + cellSize / 2
        let poursFromRightRim = entry.column >= model.level.width / 2
        let tilt = poursFromRightRim ? 48.0 : -48.0
        let angle = tilt * Double.pi / 180
        let rimOffsetX = poursFromRightRim ? 53.0 : -53.0
        let scale: CGFloat = 0.35
        let rimX = CGFloat(rimOffsetX * cos(angle) + 18 * sin(angle)) * scale
        let rimY = CGFloat(rimOffsetX * sin(angle) - 18 * cos(angle)) * scale
        let bucketCenter = CGPoint(x: centerX - rimX, y: 18)
        let originY = bucketCenter.y + rimY
        return ZStack(alignment: .topLeading) {
            if let box = model.level.boxes.first(where: { $0.id == model.fillingBoxID }) {
                let row = model.engine.boxState(id: box.id, state: model.presentationState).row
                let boxHeight = CGFloat(box.height) * cellSize + CGFloat(box.height - 1) * blockGap
                let fraction = model.fillUnits(for: box) / Double(box.capacity)
                let endY = boardHeadroom + CGFloat(row) * (cellSize + blockGap) + boxHeight * (1 - fraction)
                RoundedRectangle(cornerRadius: 2)
                    .fill(pour.color.displayColor)
                    .frame(width: 4, height: max(0, endY - originY))
                    .position(x: centerX, y: (endY + originY) / 2)
            }
            PaintArtwork(color: pour.color, quantity: pour.initialUnits - model.consumedDuringPour)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(tilt))
                .position(bucketCenter)
                .animation(.easeInOut(duration: 0.25), value: entry.column)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var slots: some View {
        HStack(spacing: 8) {
            ForEach(model.progress.state.buckets.indices, id: \.self) { slot in
                let bucket = model.displayedBucket(slot: slot)
                let canPour = model.engine.canPour(slot: slot, state: model.progress.state)
                Button { model.pour(slot: slot, reducedMotion: reduceMotionEnabled) } label: {
                    VStack(spacing: 0) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundStyle(.yellow)
                            .shadow(color: .orange, radius: 0, x: 1, y: 2)
                            .frame(height: 20)
                            .opacity(bucket != nil && !canPour && !model.busy ? 1 : 0)
                            .accessibilityHidden(true)
                        PaintArtwork(color: bucket?.color, quantity: bucket?.paintUnits)
                            .frame(maxWidth: 96)
                            .frame(height: 64)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.busy || model.outcome != .playing || !canPour)
                .accessibilityLabel(bucket.map { "\($0.color.name) bucket" } ?? "Empty bucket slot")
                .accessibilityValue(bucket.map {
                    "\($0.paintUnits) paint units, " + (model.busy ? "Pouring" : canPour ? "Ready to pour" : "Blocked")
                } ?? "Empty")
                .accessibilityHint("Pours automatically into the leftmost exposed matching boxes")
                .accessibilityIdentifier("slot-\(slot)")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var queues: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(0..<4, id: \.self) { queue in
                let tins = Array(model.level.paintQueues[queue].dropFirst(model.progress.state.queuePositions[queue]).prefix(3))
                VStack(spacing: 0) {
                    ForEach(Array(tins.enumerated()), id: \.offset) { offset, tin in
                        if offset == 0 {
                            Button { model.take(queue: queue) } label: {
                                PaintArtwork(color: tin.color, quantity: tin.paintUnits, tin: true)
                                    .frame(height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(model.busy || model.outcome != .playing || !model.engine.canTake(queue: queue, state: model.progress.state))
                            .accessibilityLabel("Queue \(queue + 1), \(tin.color.name) tin")
                            .accessibilityValue("\(tin.paintUnits) paint units")
                            .accessibilityIdentifier("queue-\(queue)")
                        } else {
                            PaintArtwork(color: tin.color, quantity: tin.paintUnits, tin: true)
                                .frame(height: 24).opacity(0.5)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder private func modal(maxHeight: CGFloat) -> some View {
        if panel == .settings {
            CartoonPanel(title: "Game settings", icon: "gearshape.fill", close: closePanel) {
                VStack(spacing: 16) {
                    Button {
                        model.requestHint()
                        panel = .hints
                    } label: {
                        SettingsEntryLabel(title: "Hint", icon: "lightbulb.fill")
                    }
                    .buttonStyle(CartoonButtonStyle())
                    .accessibilityIdentifier("hint")
                    Button { panel = .stats } label: {
                        SettingsEntryLabel(title: "Stats", icon: "chart.bar.fill")
                    }
                    .buttonStyle(CartoonButtonStyle())
                    .accessibilityIdentifier("stats")
                    Button {
                        confirmRestart = true
                        closePanel()
                    } label: {
                        SettingsEntryLabel(title: "Retry level", icon: "arrow.counterclockwise")
                    }
                    .buttonStyle(CartoonButtonStyle())
                    .accessibilityIdentifier("restart")
                }
            }
        } else if panel == .stats {
            CartoonPanel(title: "Stats", icon: "chart.bar.fill", close: closePanel) {
                VStack(spacing: 18) {
                    StatsTable(statistics: model.progress.statistics)
                    Button { confirmClearStats = true } label: {
                        SettingsEntryLabel(title: "Clear stats", icon: "eraser.fill")
                    }
                    .buttonStyle(CartoonButtonStyle())
                    .accessibilityIdentifier("clear-stats")
                }
            }
        } else if panel == .hints {
            CartoonPanel(title: "Your next 5 moves", icon: "lightbulb.fill", close: closePanel) {
                HintRiverView(presentation: model.hintPresentation)
                    .frame(maxHeight: max(180, maxHeight - 116))
            }
        } else if model.outcome != .playing && !model.busy {
            let won = model.outcome == .won
            CartoonPanel(title: won ? (model.finalLevel ? "Game Complete!" : "Level Complete!") : "No Moves Left",
                         icon: won ? "star.fill" : "arrow.counterclockwise") {
                VStack(spacing: 24) {
                    Text(won ? (model.finalLevel ? "You cleared every paint puzzle!" : "Beautiful pouring! Ready for the next puzzle?") : "A fresh start can open a new path.")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .multilineTextAlignment(.center)
                    if won {
                        Button(model.finalLevel ? "Start Again" : "Next Level") { model.advance() }
                            .buttonStyle(CartoonButtonStyle())
                            .accessibilityIdentifier("advance")
                    } else {
                        Button("Retry") { model.restart() }
                            .buttonStyle(CartoonButtonStyle())
                            .accessibilityIdentifier("retry")
                    }
                }
            }
        }
    }

    private func closePanel() {
        model.cancelHint()
        panel = nil
    }
}

enum GamePanel { case settings, hints, stats }
