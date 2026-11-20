import ColorFlowCore
import SwiftUI

struct BoardPaint {
    private static let artworkInk = ArtworkColor(red: 0.06, green: 0.10, blue: 0.17)
    private static let enamelContour = ArtworkColor(red: 0.31, green: 0.15, blue: 0.12)
    private static let cream = ArtworkColor(red: 1, green: 0.94, blue: 0.76)

    static let pointer = cream.color
    static let glintWidth: CGFloat = 1.5
    static let streamWidth: CGFloat = 4.4

    let color: PaintColor

    private var pigment: ArtworkColor { color.artworkColor }
    var rimContour: Color { Self.enamelContour.mixed(with: pigment, amount: 0.12).color }
    var surfaceGlint: Color { Self.cream.color.opacity(0.56) }
    var wellEdge: Color { Self.enamelContour.color.opacity(0.63) }

    var rim: [Color] {
        [
            pigment.mixed(with: Self.cream, amount: 0.68).color,
            pigment.color,
            pigment.mixed(with: Self.enamelContour, amount: 0.32).color
        ]
    }

    var well: [Color] {
        [0.19, 0.31].map { Self.artworkInk.mixed(with: pigment, amount: $0).color }
    }

    var surface: [Color] {
        [
            pigment.mixed(with: Self.cream, amount: 0.22).color,
            pigment.color,
            pigment.mixed(with: Self.enamelContour, amount: 0.20).color
        ]
    }

    var stream: [Color] {
        [rimContour, pigment.color, surfaceGlint, pigment.color]
    }
}

struct BoardContainerRim<Outer: InsettableShape, Well: InsettableShape>: View {
    let outer: Outer
    let well: Well
    let paint: BoardPaint
    let light: UnitPoint
    let shade: UnitPoint

    var body: some View {
        outer.fill(LinearGradient(colors: paint.rim, startPoint: light, endPoint: shade))
            .overlay {
                well.fill(LinearGradient(colors: paint.well, startPoint: light, endPoint: shade))
            }
            .overlay {
                well.strokeBorder(paint.wellEdge, lineWidth: 1.2)
            }
            .overlay {
                outer.strokeBorder(paint.rimContour, lineWidth: 1.2)
            }
    }
}

struct BoardPaintStream<Silhouette: Shape>: View {
    let paint: BoardPaint
    let silhouette: Silhouette

    var body: some View {
        LinearGradient(colors: paint.stream, startPoint: .leading, endPoint: .trailing)
            .overlay(alignment: .trailing) {
                Capsule()
                    .fill(paint.surfaceGlint)
                    .frame(width: 0.8)
                    .padding(.vertical, 1)
                    .padding(.trailing, 1.1)
            }
            .clipShape(silhouette)
    }
}
