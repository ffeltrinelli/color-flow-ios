import Foundation

/// Polar presentation of the engine's unchanged logical rows and columns.
public struct CircularGeometry: Sendable {
    public let lanes: Int
    public let bands: Int
    public let radius: Double

    public init(lanes: Int, bands: Int, radius: Double) {
        self.lanes = lanes
        self.bands = bands
        self.radius = radius
    }

    public var hubRadius: Double { radius / 4 }
    public var bandThickness: Double { (radius - hubRadius) / Double(bands) }
    public var laneAngle: Double { 2 * .pi / Double(lanes) }
    public var dividerAngle: Double { -.pi / 2 - laneAngle / 2 }

    public func innerRadius(row: Double, height: Int) -> Double {
        hubRadius + (Double(bands - height) - row) * bandThickness
    }

    public func outerRadius(row: Double) -> Double { radius - row * bandThickness }

    public func fillRadius(inner: Double, outer: Double, fraction: Double) -> Double {
        sqrt(inner * inner + min(1, max(0, fraction)) * (outer * outer - inner * inner))
    }

    /// Unwrapped negative angles prevent a presentation from taking a clockwise shortcut.
    public func rotation(from degrees: Double, to lane: Int) -> Double {
        let destination = -Double(lane) * 360 / Double(lanes)
        var distance = (degrees - destination).truncatingRemainder(dividingBy: 360)
        if distance < 0 { distance += 360 }
        return degrees - distance
    }
}
