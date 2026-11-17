import ColorFlowCore
import SwiftUI

struct CircularBoardView: View {
    @Bindable var model: GameModel
    let size: CGFloat
    let reducedMotion: Bool
    private let headroom: CGFloat = 36

    private var geometry: CircularGeometry {
        CircularGeometry(lanes: model.level.width, bands: model.level.height, radius: Double(size / 2 - 10))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                ForEach(model.engine.remainingBoxes(state: model.presentationState)) { box in
                    block(box)
                }
                divider
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(model.circularRotation))
            .offset(y: headroom)
            pourPoint
            if let pour = model.pour, !reducedMotion { pouring(pour) }
        }
        .frame(width: size, height: size + headroom)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Circular puzzle board")
        .accessibilityIdentifier("board")
        .accessibilityValue(model.busy ? "Pouring" : "Ready")
    }

    private func block(_ box: BoxDefinition) -> some View {
        let row = Double(model.engine.boxState(id: box.id, state: model.presentationState).row)
        let color = box.color.displayColor
        let shape = CircularBlockShape(row: row, box: box, lanes: model.level.width, bands: model.level.height)
        var paint = shape
        paint.fraction = model.fillUnits(for: box) / Double(box.capacity)
        return shape.fill(color.opacity(0.16))
            .overlay { paint.fill(color) }
            .overlay { shape.stroke(color, lineWidth: 2) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.busy ? "Pouring" : model.boxSummary(box))
            .accessibilityIdentifier("box-\(box.id)")
    }

    private var divider: some View {
        Canvas { context, canvas in
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let angle = geometry.dividerAngle
            func point(_ radius: Double, _ angle: Double) -> CGPoint {
                CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }
            let headRadius = geometry.radius + 3
            var pole = Path()
            pole.move(to: point(geometry.hubRadius, angle))
            pole.addLine(to: point(headRadius, angle))
            context.stroke(pole, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            let head = point(headRadius, angle)
            context.fill(Path(ellipseIn: CGRect(x: head.x - 3, y: head.y - 3, width: 6, height: 6)), with: .color(.white))
            // Head and arrow share one radial envelope; their gap runs along the rim.
            let start = angle - 7 / headRadius
            let end = start - 0.18
            var arrow = Path()
            arrow.addArc(center: center, radius: headRadius, startAngle: .radians(start),
                         endAngle: .radians(end), clockwise: true)
            let tip = point(headRadius, end)
            let tangent = CGPoint(x: sin(end), y: -cos(end))
            let normal = CGPoint(x: cos(end), y: sin(end))
            arrow.move(to: CGPoint(x: tip.x - 4 * tangent.x + 2.5 * normal.x,
                                  y: tip.y - 4 * tangent.y + 2.5 * normal.y))
            arrow.addLine(to: tip)
            arrow.addLine(to: CGPoint(x: tip.x - 4 * tangent.x - 2.5 * normal.x,
                                     y: tip.y - 4 * tangent.y - 2.5 * normal.y))
            context.stroke(arrow, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var pourPoint: some View {
        Path { path in
            let y = headroom + size / 2 - geometry.radius - 6
            path.move(to: CGPoint(x: size / 2 - 4, y: y - 5))
            path.addLine(to: CGPoint(x: size / 2 + 4, y: y - 5))
            path.addLine(to: CGPoint(x: size / 2, y: y))
            path.closeSubpath()
        }
        .fill(.white)
        .accessibilityHidden(true)
    }

    private func pouring(_ pour: PourPresentation) -> some View {
        let tilt = -48.0
        let angle = tilt * .pi / 180
        let rimX = (-53 * cos(angle) + 18 * sin(angle)) * 0.35
        let rimY = (-53 * sin(angle) - 18 * cos(angle)) * 0.35
        let originY = 18 + rimY
        return ZStack(alignment: .topLeading) {
            if let box = model.level.boxes.first(where: { $0.id == model.fillingBoxID }) {
                let row = Double(model.engine.boxState(id: box.id, state: model.presentationState).row)
                let inner = geometry.innerRadius(row: row, height: box.height) + 2
                let outer = geometry.outerRadius(row: row) - 2
                let filled = geometry.fillRadius(inner: inner, outer: outer,
                                                fraction: model.fillUnits(for: box) / Double(box.capacity))
                let endY = headroom + size / 2 - filled
                Rectangle().fill(pour.color.displayColor)
                    .frame(width: 3, height: max(0, endY - originY))
                    .position(x: size / 2, y: (endY + originY) / 2)
            }
            PaintArtwork(color: pour.color, quantity: pour.initialUnits - model.consumedDuringPour)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(tilt))
                .position(x: size / 2 - rimX, y: 18)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CircularBlockShape: Shape {
    var row: Double
    let box: BoxDefinition
    let lanes: Int
    let bands: Int
    var fraction: Double = 1

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(row, fraction) }
        set { row = newValue.first; fraction = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0 else { return Path() }
        let geometry = CircularGeometry(lanes: lanes, bands: bands, radius: Double(min(rect.width, rect.height) / 2 - 10))
        let inner = geometry.innerRadius(row: row, height: box.height) + 2
        let outer = geometry.outerRadius(row: row) - 2
        let fill = geometry.fillRadius(inner: inner, outer: outer, fraction: fraction)
        let inset = 2 / ((inner + outer) / 2)
        let start = geometry.dividerAngle + Double(box.column) * geometry.laneAngle + inset
        let end = geometry.dividerAngle + Double(box.column + box.width) * geometry.laneAngle - inset
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: fill, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}
