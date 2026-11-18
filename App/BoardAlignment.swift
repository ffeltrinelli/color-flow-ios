import ColorFlowCore

struct AlignmentTransition {
    let rotation: Double
    let duration: Double
}

protocol BoardAlignment {
    func restoredRotation(lane: Int) -> Double
    func transition(from rotation: Double, previousEntry: Cell?, to entry: Cell) -> AlignmentTransition
}

struct SquareAlignment: BoardAlignment {
    func restoredRotation(lane: Int) -> Double { 0 }

    func transition(from rotation: Double, previousEntry: Cell?, to entry: Cell) -> AlignmentTransition {
        AlignmentTransition(rotation: 0, duration: previousEntry != nil && previousEntry?.column != entry.column ? 0.25 : 0)
    }
}

struct CircularAlignment: BoardAlignment {
    let lanes: Int

    func restoredRotation(lane: Int) -> Double { -Double(lane) * 360 / Double(lanes) }

    func transition(from rotation: Double, previousEntry: Cell?, to entry: Cell) -> AlignmentTransition {
        let geometry = CircularGeometry(lanes: lanes, bands: 1, radius: 1)
        let target = geometry.rotation(from: rotation, to: entry.column)
        let distance = rotation - target
        return AlignmentTransition(rotation: target, duration: distance > 0 ? 0.2 + distance / 360 * 0.55 : 0)
    }
}

extension BoardKind {
    func alignment(lanes: Int) -> any BoardAlignment {
        switch self {
        case .square: SquareAlignment()
        case .circular: CircularAlignment(lanes: lanes)
        }
    }

    var pouringHint: String {
        switch self {
        case .square: "Pours automatically into the leftmost exposed matching boxes"
        case .circular: "Searches clockwise from the lane beneath the pour pointer for exposed matching blocks"
        }
    }
}
