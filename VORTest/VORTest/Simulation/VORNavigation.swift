import CoreGraphics
import Foundation

/// Pure VOR navigation math: no SwiftUI, no view geometry. Callers resolve
/// screen/map positions first (see `MapView`'s `point(for:in:)` and
/// `pixelsPerNM(in:)`) and pass plain points and distances in here.
enum VORNavigation {
    /// Wraps an angle to the range −180…180.
    static func normalize180(_ angle: Double) -> Double {
        var result = angle.truncatingRemainder(dividingBy: 360)
        if result > 180 { result -= 360 }
        if result < -180 { result += 360 }
        return result
    }

    /// Computes the CDI needle deflection and TO/FROM flag for a radio tuned
    /// to a station at `stationPosition`, with the OBS set to `obs`, given the
    /// plane's position. Both points are in the same unscaled map space.
    static func cdiReading(planePosition: CGPoint, stationPosition: CGPoint,
                           obs: Double, cdiMax: Double) -> CDIReading {
        // Vector from station to plane (map space: +x east, +y south).
        let vx = planePosition.x - stationPosition.x
        let vy = planePosition.y - stationPosition.y

        // The radial the plane is on = bearing FROM the station (0° = north/up).
        var radial = atan2(vx, -vy) * 180 / .pi
        if radial < 0 { radial += 360 }

        // Difference between the plane's radial and the selected course.
        let diff = normalize180(radial - obs)
        let flag: CDIReading.Flag = abs(diff) <= 90 ? .from : .to

        // Angular deviation from the selected course line (0–90°), full scale at cdiMax.
        let deviationAngle = flag == .from ? abs(diff) : 180 - abs(diff)

        // Which side of the course line the plane sits on decides needle direction:
        // plane to the right of course → course is to the left → needle deflects left.
        let obsRad = obs * .pi / 180
        let planeIsRightOfCourse = (vx * cos(obsRad) + vy * sin(obsRad)) > 0
        let sign: Double = planeIsRightOfCourse ? -1 : 1

        let deflection = sign * min(deviationAngle, cdiMax) / cdiMax
        return CDIReading(deflection: deflection, flag: flag)
    }

    /// Distance between two map-space points, converted to nautical miles
    /// using the chart's pixels-per-NM scale.
    static func distanceNM(from planePoint: CGPoint, to stationPoint: CGPoint,
                           pixelsPerNM: CGFloat) -> Double {
        guard pixelsPerNM > 0 else { return .infinity }
        return hypot(Double(planePoint.x - stationPoint.x),
                     Double(planePoint.y - stationPoint.y)) / Double(pixelsPerNM)
    }

    /// The station whose identifier matches `ident` (case-insensitive), if any.
    static func station(withIdent ident: String, in stations: [VORStation]) -> VORStation? {
        let key = ident.trimmingCharacters(in: .whitespaces).uppercased()
        guard !key.isEmpty else { return nil }
        return stations.first { $0.ident == key }
    }

    /// Distance in nautical miles between two normalized map-image points
    /// (0...1, same convention as `VORStation.location`), given the chart's
    /// real-world width and height. Unlike `distanceNM(from:to:pixelsPerNM:)`
    /// this needs no screen geometry, so it works before any view has laid out.
    static func distanceNM(fromNormalized a: CGPoint, toNormalized b: CGPoint,
                           mapWidthNM: Double, mapHeightNM: Double) -> Double {
        let eastNM = Double(a.x - b.x) * mapWidthNM
        let southNM = Double(a.y - b.y) * mapHeightNM
        return hypot(eastNM, southNM)
    }
}
