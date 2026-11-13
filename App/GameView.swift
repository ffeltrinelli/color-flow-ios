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
            let gridSize = min(geometry.size.width - 32, geometry.size.height - 360, 400)
            VStack(spacing: 4) {
                header
                    .frame(height: 36)
                board(size: gridSize)
                slots
                    .frame(height: 72)
                queues
                    .frame(height: 120)
                result
                    .frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
            }
            .accessibilityLabel("Restart level")
            .accessibilityIdentifier("restart")
            .disabled(model.busy || model.outcome != .playing)
        }
    }

    private func board(size: CGFloat) -> some View {
        let gap: CGFloat = 4
        let cellSize = (size - CGFloat(model.level.width - 1) * gap) / CGFloat(model.level.width)
        let height = cellSize * CGFloat(model.level.height) + gap * CGFloat(model.level.height - 1)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: gap) {
                ForEach(0..<model.level.height, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<model.level.width, id: \.self) { column in
                            cell(row: row, column: column, size: cellSize)
                        }
                    }
                }
            }
            .offset(y: 60)
            if let pour = model.pour {
                pourOverlay(pour, cellSize: cellSize, gap: gap)
            }
        }
        .frame(width: size, height: height + 60, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board")
        .accessibilityValue(model.busy ? "Pouring" : "Ready")
    }

    private func cell(row: Int, column: Int, size: CGFloat) -> some View {
        let cell = Cell(row: row, column: column)
        let color = model.level.colors[row][column]
        let painted = model.isPainted(cell)
        let highlighted = model.preview(column: column).contains(cell)
        return Button { model.pour(column: column, reducedMotion: reduceMotionEnabled) } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(painted ? color.displayColor : highlighted ? color.displayColor.opacity(0.35) : background)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(highlighted ? .white : painted ? .white.opacity(0.25) : color.displayColor,
                                      lineWidth: painted ? 2 : 4)
                }
                .shadow(color: highlighted ? color.displayColor.opacity(0.7) : .clear, radius: 5)
                .phaseAnimator([false, true]) { content, pulse in
                    content.opacity(highlighted && pulse && !reduceMotionEnabled ? 0.72 : 1)
                } animation: { _ in .easeInOut(duration: 0.8) }
                .frame(width: size, height: size)
        }
        .buttonStyle(GridCellStyle())
        .disabled(!highlighted || model.busy)
        .accessibilityLabel("Row \(row + 1), column \(column + 1), \(color.name)")
        .accessibilityValue(painted ? "Painted" : highlighted ? "Ready to pour" : "Unpainted")
        .accessibilityIdentifier("cell-\(row)-\(column)")
    }

    private func pourOverlay(_ pour: PourPresentation, cellSize: CGFloat, gap: CGFloat) -> some View {
        let centerX = CGFloat(pour.column) * (cellSize + gap) + cellSize / 2
        // Pour toward the board interior so edge columns never clip the bucket.
        let poursFromRightRim = pour.column >= model.level.width / 2
        let tilt = poursFromRightRim ? 48.0 : -48.0
        let angle = tilt * Double.pi / 180
        let rimOffsetX = poursFromRightRim ? 53.0 : -53.0
        let scale: CGFloat = 0.5
        let rimX = CGFloat(rimOffsetX * cos(angle) + 18 * sin(angle)) * scale
        let rimY = CGFloat(rimOffsetX * sin(angle) - 18 * cos(angle)) * scale
        let bucketCenter = CGPoint(x: centerX - rimX, y: 25)
        let originY = bucketCenter.y + rimY
        return ZStack(alignment: .topLeading) {
            if let row = model.streamEndRow {
                let endY = 60 + CGFloat(row) * (cellSize + gap) + cellSize / 2
                RoundedRectangle(cornerRadius: 3)
                    .fill(pour.color.displayColor)
                    .frame(width: 6, height: max(0, endY - originY))
                    .position(x: centerX, y: (endY + originY) / 2)
            }
            PaintArtwork(color: pour.color, quantity: pour.initialUnits - model.filledDuringPour.count)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(model.tilted ? tilt : 0))
                .position(bucketCenter)
                .animation(reduceMotionEnabled ? nil : .easeInOut(duration: 0.24), value: model.tilted)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var slots: some View {
        HStack(spacing: 8) {
            ForEach(model.progress.state.buckets.indices, id: \.self) { slot in
                let bucket = model.presentationState.buckets[slot]
                Button { model.select(slot: slot) } label: {
                    PaintArtwork(color: bucket?.color, quantity: bucket?.paintUnits)
                        .frame(maxWidth: 96)
                        .frame(height: 72)
                        .background {
                            if model.progress.state.selectedSlot == slot {
                                RoundedRectangle(cornerRadius: 10).stroke(.white, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(bucket == nil || model.busy || model.outcome != .playing)
                .accessibilityLabel(bucket.map { "\($0.color.name) bucket" } ?? "Empty bucket slot")
                .accessibilityValue(bucket.map { "\($0.paintUnits) paint units" } ?? "Empty")
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
                                PaintArtwork(color: tin.color, quantity: tin.paintUnits, tin: true).frame(height: 48)
                            }
                            .buttonStyle(.plain)
                            .disabled(model.busy || model.outcome != .playing || !model.engine.canTake(queue: queue, state: model.progress.state))
                            .accessibilityLabel("Queue \(queue + 1), \(tin.color.name) tin")
                            .accessibilityValue("\(tin.paintUnits) paint units")
                            .accessibilityIdentifier("queue-\(queue)")
                        } else {
                            PaintArtwork(color: tin.color, quantity: tin.paintUnits, tin: true)
                                .frame(height: 34).opacity(0.5)
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

private struct GridCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.85 : 1)
    }
}
