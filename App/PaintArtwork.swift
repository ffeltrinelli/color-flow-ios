import ColorFlowCore
import SwiftUI

extension PaintColor {
    var displayColor: Color {
        switch self {
        case .red: Color(red: 0.96, green: 0.45, blue: 0.43)
        case .green: Color(red: 0.56, green: 0.83, blue: 0.54)
        case .blue: Color(red: 0.40, green: 0.77, blue: 0.93)
        case .yellow: Color(red: 0.95, green: 0.78, blue: 0.36)
        case .purple: Color(red: 0.73, green: 0.62, blue: 0.95)
        }
    }
}

struct PaintArtwork: View {
    let color: PaintColor?
    let quantity: Int?
    var tin = false

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 160, size.height / 160)
            context.translateBy(x: (size.width - 160 * scale) / 2, y: (size.height - 160 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let metal = Color(red: 0.65, green: 0.72, blue: 0.78)
            let paint = color?.displayColor ?? Color(red: 0.20, green: 0.27, blue: 0.36)
            if !tin {
                var handle = Path()
                handle.move(to: CGPoint(x: 27, y: 62))
                handle.addCurve(to: CGPoint(x: 133, y: 62), control1: CGPoint(x: 27, y: 12), control2: CGPoint(x: 133, y: 12))
                context.stroke(handle, with: .color(metal), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            }
            var body = Path()
            body.move(to: CGPoint(x: tin ? 33 : 27, y: tin ? 49 : 62))
            body.addLine(to: CGPoint(x: tin ? 127 : 133, y: tin ? 49 : 62))
            body.addLine(to: CGPoint(x: tin ? 124 : 119, y: 136))
            body.addQuadCurve(to: CGPoint(x: tin ? 36 : 41, y: 136), control: CGPoint(x: 80, y: 155))
            body.closeSubpath()
            context.fill(body, with: .color(paint))
            context.stroke(body, with: .color(metal), lineWidth: 3)
            let lid = CGRect(x: tin ? 29 : 27, y: tin ? 35 : 51, width: tin ? 102 : 106, height: 22)
            context.fill(Path(ellipseIn: lid), with: .color(tin ? metal : .white.opacity(0.35)))
            context.stroke(Path(ellipseIn: lid), with: .color(metal), lineWidth: 3)
            let text = Text(quantity.map(String.init) ?? "+")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(color == nil ? .white : Color(red: 0.08, green: 0.16, blue: 0.24))
            context.draw(text, at: CGPoint(x: 80, y: 108))
        }
        .accessibilityHidden(true)
    }
}
