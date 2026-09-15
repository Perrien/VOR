import CoreGraphics
import Foundation

/// Pure flight-movement math: no SwiftUI. Advances a position by heading and
/// speed over an elapsed time, then clamps it to the map bounds.
enum FlightPhysics {
    /// Returns the new position after flying `speedKnots` on `heading` for
    /// `elapsed` seconds, starting from `position`. `pixelsPerNM` converts the
    /// simulated distance into map-space points; `bounds` clamps the result to
    /// the map area.
    static func advance(position: CGPoint, heading: Double, speedKnots: Double,
                        elapsed: TimeInterval, pixelsPerNM: CGFloat, bounds: CGSize) -> CGPoint {
        guard pixelsPerNM > 0 else { return position }

        let distanceNM = max(0, speedKnots) * elapsed / 3_600
        let radians = heading * .pi / 180
        let distanceInPoints = CGFloat(distanceNM) * pixelsPerNM
        let proposed = CGPoint(
            x: position.x + sin(radians) * distanceInPoints,
            y: position.y - cos(radians) * distanceInPoints
        )

        return CGPoint(
            x: min(max(proposed.x, 0), bounds.width),
            y: min(max(proposed.y, 0), bounds.height)
        )
    }
}
