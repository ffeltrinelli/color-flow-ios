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
            BoardAphorism(aphorism: model.aphorism, size: size, revealedFraction: model.revealedFraction,
                          reducedMotion: reducedMotion)
                .offset(y: boardHeadroom)
            ForEach(model.presentedBoxes) { box in
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
        let size = containerSize(box, cellSize: cellSize)
        let fraction = model.fillUnits(for: box) / Double(box.capacity)
        return SquareContainer(size: size, paint: BoardPaint(color: box.color), fraction: fraction)
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
                let height = containerSize(box, cellSize: cellSize).height
                let fraction = model.fillUnits(for: box) / Double(box.capacity)
                let top = boardHeadroom + CGFloat(row) * (cellSize + blockGap)
                let endY = top + SquareContainer.surfaceY(height: height, fraction: fraction)
                BoardPaintStream(paint: BoardPaint(color: pour.color), silhouette: Capsule())
                    .frame(width: BoardPaint.streamWidth, height: max(0, endY - originY))
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

    private func containerSize(_ box: BoxDefinition, cellSize: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(box.width) * (cellSize + blockGap) - blockGap,
            height: CGFloat(box.height) * (cellSize + blockGap) - blockGap
        )
    }

    private func boxSummary(_ box: BoxDefinition) -> String {
        let current = model.engine.boxState(id: box.id, state: model.presentationState)
        return "\(box.color.name), row \(current.row + 1), column \(box.column + 1), \(box.width) by \(box.height), \(current.filledUnits) of \(box.capacity) paint units"
    }
}

private struct SquareContainer: View {
    private static let rimDepth: CGFloat = 4.2

    let size: CGSize
    let paint: BoardPaint
    let fraction: Double

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: 6.2, style: .continuous)
        let well = outer.inset(by: Self.rimDepth)
        return BoardContainerRim(outer: outer, well: well, paint: paint, light: .topLeading, shade: .bottomTrailing)
            .overlay {
                paintSurface.clipShape(well)
            }
            .frame(width: size.width, height: size.height)
    }

    private var paintSurface: some View {
        let height = size.height - Self.rimDepth - Self.surfaceY(height: size.height, fraction: fraction)
        return ZStack(alignment: .bottom) {
            Color.clear
            Rectangle()
                .fill(LinearGradient(colors: paint.surface, startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(paint.surfaceGlint)
                        .frame(width: max(0, size.width - 2 * Self.rimDepth) * 0.9,
                               height: min(BoardPaint.glintWidth, height / 2))
                        .padding(.top, 1)
                        .opacity(height >= 2 ? 1 : 0)
                }
                .frame(height: height)
                .clipped()
                .padding(.bottom, Self.rimDepth)
        }
    }

    static func surfaceY(height: CGFloat, fraction: Double) -> CGFloat {
        height - rimDepth - max(0, height - 2 * rimDepth) * CGFloat(min(1, max(0, fraction)))
    }
}
