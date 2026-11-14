import ColorFlowCore
import SwiftUI

struct GameView: View {
    @Bindable var model: GameModel
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmRestart = false
    private var reduceMotionEnabled: Bool {
        reducedMotion || (ProcessInfo.processInfo.environment["COLOR_FLOW_UI_TEST"] == "1" &&
                          ProcessInfo.processInfo.environment["COLOR_FLOW_REDUCE_MOTION"] == "1")
    }
    private let background = Color(red: 0.067, green: 0.094, blue: 0.153)

    var body: some View {
        GeometryReader { geometry in
            let gridSize = min(geometry.size.width - 8, geometry.size.height - 276, 440)
            VStack(spacing: 2) {
                header
                    .frame(height: 44)
                board(size: gridSize)
                slots
                    .frame(height: 64)
                queues
                    .frame(height: 92)
                result
                    .frame(height: 32)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Restart this level?", isPresented: $confirmRestart) {
            Button("Restart Level", role: .destructive) { model.restart() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Progress Not Saved", isPresented: Binding(get: { model.saveError != nil }, set: { if !$0 { model.saveError = nil } })) {
            Button("Try Again") { model.save() }
        } message: { Text(model.saveError ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.finishAnimation() }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Level \(model.level.id)").font(.headline)
                    .accessibilityIdentifier("level-number")
                Text(model.level.difficulty.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("level-difficulty")
            }
            Spacer()
            Button { confirmRestart = true } label: {
                Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Restart level")
            .accessibilityIdentifier("restart")
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
                    PaintArtwork(color: bucket?.color, quantity: bucket?.paintUnits)
                        .frame(maxWidth: 96)
                        .frame(height: 64)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            if bucket != nil, !canPour, !model.busy {
                                Text("Blocked").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
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

    @ViewBuilder private var result: some View {
        if model.busy {
            Color.clear
        } else {
            switch model.outcome {
            case .playing: Color.clear
            case .lost:
                HStack {
                    Text("No Moves Left").font(.headline)
                    Button("Retry") { model.restart() }.buttonStyle(.borderedProminent).accessibilityIdentifier("retry")
                }
            case .won:
                HStack {
                    Text(model.finalLevel ? "Game Complete" : "Level Complete!").font(.headline)
                    Button(model.finalLevel ? "Start Again" : "Next Level") { model.advance() }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("advance")
                }
            }
        }
    }
}
