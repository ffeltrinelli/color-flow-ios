import ColorFlowCore
import SwiftUI

struct SquareBoardView: View {
    @Bindable var model: GameModel
    let size: CGFloat
    let reducedMotion: Bool
    private let boardHeadroom: CGFloat = 36
    private let blockGap: CGFloat = 2

    var body: some View {
        let cellSize = (size - CGFloat(model.level.width - 1) * blockGap) / CGFloat(model.level.width)
        return ZStack(alignment: .topLeading) {
            ForEach(model.engine.remainingBoxes(state: model.presentationState)) { box in
                let row = model.engine.boxState(id: box.id, state: model.presentationState).row
                block(box, cellSize: cellSize)
                    .offset(x: CGFloat(box.column) * (cellSize + blockGap),
                            y: boardHeadroom + CGFloat(row) * (cellSize + blockGap))
            }
            if let pour = model.pour, let entry = model.pourDestination, !reducedMotion {
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
            .accessibilityLabel(model.busy ? "Pouring" : boxSummary(box))
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

    private func boxSummary(_ box: BoxDefinition) -> String {
        let current = model.engine.boxState(id: box.id, state: model.presentationState)
        return "\(box.color.name), row \(current.row + 1), column \(box.column + 1), \(box.width) by \(box.height), \(current.filledUnits) of \(box.capacity) paint units"
    }
}
