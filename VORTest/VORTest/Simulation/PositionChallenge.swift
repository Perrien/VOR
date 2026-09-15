import CoreGraphics
import Foundation

/// A "find your position" training exercise: a hidden target exists somewhere
/// on the chart, the player uses the NAV radios to plot radials toward it,
/// then drags a guess marker to where they think it is and checks placement.
enum PositionChallenge {
    /// The distance between a guess and the target, once checked. Both
    /// points are in the same unscaled map space as `MapView.planePosition`.
    struct Result {
        let guess: CGPoint
        let target: CGPoint
        let errorNM: Double
    }

    /// Where things stand: no challenge running, a target hidden and waiting
    /// for a guess (normalized 0...1, same convention as `VORStation.location`
    /// — it has no map-space meaning until converted against an `imageRect`),
    /// or a guess already scored against it.
    enum State {
        case inactive
        case active(target: CGPoint)
        case revealed(Result)
    }

    /// A random target in normalized map-image space (0...1), inset from the
    /// edges so it never lands in a corner, and solvable: reachable by at
    /// least `minInRangeStations` VORs, so the player always has enough
    /// radials to fix a position (one station only gives a radial, not a
    /// distance). Tries up to `maxAttempts` random candidates and falls back
    /// to the most-reachable one found if none clears the threshold.
    static func randomTarget(stations: [VORStation], mapWidthNM: Double, mapHeightNM: Double,
                             minInRangeStations: Int = 3, inset: Double = 0.1,
                             maxAttempts: Int = 500) -> CGPoint {
        let range = inset...(1 - inset)
        var best: (point: CGPoint, count: Int)?

        for _ in 0..<maxAttempts {
            let candidate = CGPoint(x: Double.random(in: range), y: Double.random(in: range))
            let count = stations.count { station in
                VORNavigation.distanceNM(fromNormalized: candidate, toNormalized: station.relativePosition,
                                         mapWidthNM: mapWidthNM, mapHeightNM: mapHeightNM)
                    <= station.rangeNM
            }
            if count >= minInRangeStations { return candidate }
            if best == nil || count > best!.count { best = (candidate, count) }
        }

        return best?.point ?? CGPoint(x: 0.5, y: 0.5)
    }

    /// Scores a guess against the target, both in the same unscaled map
    /// space, converting the distance to nautical miles.
    static func score(guess: CGPoint, target: CGPoint, pixelsPerNM: CGFloat) -> Result {
        let errorNM = VORNavigation.distanceNM(from: guess, to: target, pixelsPerNM: pixelsPerNM)
        return Result(guess: guess, target: target, errorNM: errorNM)
    }
}
