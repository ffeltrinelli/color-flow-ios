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
            BoardAphorism(aphorism: model.aphorism, size: size, revealedFraction: model.revealedFraction,
                          reducedMotion: reducedMotion)
                .offset(y: headroom)
            ZStack {
                ForEach(model.presentedBoxes) { box in
                    block(box)
                }
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(model.boardRotation))
            .offset(y: headroom)
            pourPoint
            if let pour = model.pour, !reducedMotion { pouring(pour) }
        }
        .frame(width: size, height: size + headroom)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Circular puzzle board, lane \(model.presentationState.alignedLane + 1) beneath the pour pointer")
        .accessibilityIdentifier("board")
        .accessibilityValue(model.busy ? "Pouring" : "Ready")
    }

    private func block(_ box: BoxDefinition) -> some View {
        let row = Double(model.engine.boxState(id: box.id, state: model.presentationState).row)
        let paint = BoardPaint(color: box.color)
        let outer = CircularContainerShape(row: row, box: box, geometry: geometry)
        let well = outer.well
        let fraction = model.fillUnits(for: box) / Double(box.capacity)
        var fill = well
        fill.fraction = fraction
        fill.layer = .paint
        var glint = fill
        glint.layer = .surfaceGlint

        let angle = outer.sector.centerAngle
        let light = gradientPoint(radius: outer.sector.outer, angle: angle)
        let shade = gradientPoint(radius: outer.sector.inner, angle: angle)
        let surface = gradientPoint(radius: well.sector.fillRadius(fraction), angle: angle)
        return BoardContainerRim(outer: outer, well: well, paint: paint, light: light, shade: shade)
            .overlay {
                fill.fill(LinearGradient(colors: paint.surface, startPoint: surface, endPoint: shade))
                    .overlay { glint.fill(paint.surfaceGlint) }
                    .clipShape(well)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.busy ? "Pouring" : boxSummary(box))
            .accessibilityIdentifier("box-\(box.id)")
    }

    private func gradientPoint(radius: Double, angle: Double) -> UnitPoint {
        UnitPoint(x: 0.5 + CGFloat(radius * cos(angle)) / size, y: 0.5 + CGFloat(radius * sin(angle)) / size)
    }

    private func boxSummary(_ box: BoxDefinition) -> String {
        let current = model.engine.boxState(id: box.id, state: model.presentationState)
        return "\(box.color.name), band \(current.row + 1), lane \(box.column + 1), \(box.width) lanes by \(box.height) bands, \(current.filledUnits) of \(box.capacity) paint units"
    }

    private var pourPoint: some View {
        Path { path in
            let x = size / 2
            let y = headroom + size / 2 - CGFloat(geometry.radius) - 5
            path.move(to: CGPoint(x: x - 5, y: y - 7))
            path.addLine(to: CGPoint(x: x + 5, y: y - 7))
            path.addQuadCurve(to: CGPoint(x: x + 1.5, y: y), control: CGPoint(x: x + 4.5, y: y - 3))
            path.addQuadCurve(to: CGPoint(x: x - 1.5, y: y), control: CGPoint(x: x, y: y + 1.5))
            path.addQuadCurve(to: CGPoint(x: x - 5, y: y - 7), control: CGPoint(x: x - 4.5, y: y - 3))
            path.closeSubpath()
        }
        .fill(BoardPaint.pointer)
        .accessibilityHidden(true)
    }

    private func pouring(_ pour: PourPresentation) -> some View {
        let tilt = -48.0
        let angle = tilt * .pi / 180
        let rimX = CGFloat((-53 * cos(angle) + 18 * sin(angle)) * 0.35)
        let rimY = CGFloat((-53 * sin(angle) - 18 * cos(angle)) * 0.35)
        let originY = 18 + rimY
        return ZStack(alignment: .topLeading) {
            if let box = model.level.boxes.first(where: { $0.id == model.fillingBoxID }) {
                let row = Double(model.engine.boxState(id: box.id, state: model.presentationState).row)
                let well = CircularContainerShape(row: row, box: box, geometry: geometry).well
                let distanceToCenter = headroom + size / 2 - originY
                let stream = CircularStreamShape(
                    well: well.sector,
                    fraction: model.fillUnits(for: box) / Double(box.capacity)
                )
                BoardPaintStream(paint: BoardPaint(color: pour.color), silhouette: stream)
                    .frame(width: BoardPaint.streamWidth, height: distanceToCenter)
                    .position(x: size / 2, y: originY + distanceToCenter / 2)
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

private struct CircularStreamShape: Shape {
    let well: CircularSector
    var fraction: Double

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let length = max(0, rect.height - CGFloat(well.fillRadius(fraction)))
        return Capsule().path(in: CGRect(origin: rect.origin, size: CGSize(width: rect.width, height: length)))
    }
}

private struct CircularContainerShape: InsettableShape {
    enum Layer {
        case rim, paint, surfaceGlint
    }

    var row: Double
    let box: BoxDefinition
    let geometry: CircularGeometry
    var fraction: Double = 1
    var layer = Layer.rim

    private var edgeInset = 0.95
    private var cornerRadius = 3.6

    init(row: Double, box: BoxDefinition, geometry: CircularGeometry) {
        self.row = row
        self.box = box
        self.geometry = geometry
    }

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(row, fraction) }
        set { row = newValue.first; fraction = newValue.second }
    }

    var well: Self {
        var well = inset(by: 3.2)
        well.cornerRadius = 2
        return well
    }

    func inset(by amount: CGFloat) -> Self {
        var shape = self
        shape.edgeInset += Double(amount)
        shape.cornerRadius = max(0, cornerRadius - Double(amount))
        return shape
    }

    var sector: CircularSector {
        let inner = geometry.innerRadius(row: row, height: box.height) + edgeInset
        let outer = geometry.outerRadius(row: row) - edgeInset
        let angleInset = edgeInset / ((inner + outer) / 2)
        let start = geometry.laneBoundaryAngle + Double(box.column) * geometry.laneAngle + angleInset
        let end = geometry.laneBoundaryAngle + Double(box.column + box.width) * geometry.laneAngle - angleInset
        return CircularSector(geometry: geometry, inner: inner, outer: outer, start: start, end: end)
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0 else { return Path() }
        let sector = sector
        let center = CGPoint(x: rect.midX, y: rect.midY)
        switch layer {
        case .rim:
            return sector.outline(center: center, cornerRadius: cornerRadius)
        case .paint:
            return sector.paint(center: center, fraction: fraction)
        case .surfaceGlint:
            return sector.glint(center: center, fraction: fraction)
        }
    }
}

private struct CircularSector {
    let geometry: CircularGeometry
    let inner: Double
    let outer: Double
    let start: Double
    let end: Double

    var centerAngle: Double { (start + end) / 2 }

    func fillRadius(_ fraction: Double) -> Double {
        geometry.fillRadius(inner: inner, outer: outer, fraction: fraction)
    }

    func outline(center: CGPoint, cornerRadius: Double) -> Path {
        ring(center: center, inner: inner, outer: outer, from: start, to: end, cornerRadius: cornerRadius)
    }

    func paint(center: CGPoint, fraction: Double) -> Path {
        // The well mask owns the antialiasing along the sides and bottom of the paint.
        let bleed = 0.75
        return ring(
            center: center, inner: inner - bleed, outer: fillRadius(fraction),
            from: start - bleed / inner, to: end + bleed / inner, cornerRadius: 0
        )
    }

    func glint(center: CGPoint, fraction: Double) -> Path {
        let width = Double(BoardPaint.glintWidth)
        let crest = fillRadius(fraction) - 0.85
        guard crest > inner + width else { return Path() }
        let endInset = (end - start) * 0.05
        return ring(
            center: center, inner: crest - width, outer: crest,
            from: start + endInset, to: end - endInset, cornerRadius: width / 2
        )
    }

    private func ring(center: CGPoint, inner: Double, outer: Double, from start: Double, to end: Double,
                      cornerRadius: Double) -> Path {
        guard inner > 0, outer > inner, end > start else { return Path() }
        func point(at radius: Double, angle: Double) -> CGPoint {
            CGPoint(x: center.x + CGFloat(radius * cos(angle)), y: center.y + CGFloat(radius * sin(angle)))
        }

        let corner = min(cornerRadius, (outer - inner) / 2, (end - start) * inner / 3)
        let outerTrim = corner / outer
        let innerTrim = corner / inner
        var path = Path()
        path.move(to: point(at: outer, angle: start + outerTrim))
        path.addArc(center: center, radius: CGFloat(outer), startAngle: .radians(start + outerTrim),
                    endAngle: .radians(end - outerTrim), clockwise: false)
        path.addQuadCurve(to: point(at: outer - corner, angle: end), control: point(at: outer, angle: end))
        path.addLine(to: point(at: inner + corner, angle: end))
        path.addQuadCurve(to: point(at: inner, angle: end - innerTrim), control: point(at: inner, angle: end))
        path.addArc(center: center, radius: CGFloat(inner), startAngle: .radians(end - innerTrim),
                    endAngle: .radians(start + innerTrim), clockwise: true)
        path.addQuadCurve(to: point(at: inner + corner, angle: start), control: point(at: inner, angle: start))
        path.addLine(to: point(at: outer - corner, angle: start))
        path.addQuadCurve(to: point(at: outer, angle: start + outerTrim), control: point(at: outer, angle: start))
        path.closeSubpath()
        return path
    }
}
