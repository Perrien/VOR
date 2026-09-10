import SwiftUI

/// The map of Myosia: the continent artwork drawn over an ocean fill.
///
/// The artwork keeps its own aspect ratio (letterboxed inside the map area),
/// so `fittedRect(in:)` is the single source of truth for where the map sits —
/// stations and the plane are positioned against that same rect.
struct FlatMap: View {
    /// The rect the map image occupies within the map area.
    let imageRect: CGRect

    /// The ocean fill shown around the letterboxed map (SVG ocean base #a9c9d4).
    static let oceanColor = Color(red: 169 / 255, green: 201 / 255, blue: 212 / 255)

    // Native pixel dimensions of the source map artwork.
    private static let mapAspect: CGFloat = 1748.0 / 1254.0

    /// Aspect-fits the map artwork within `area`, centered.
    static func fittedRect(in area: CGSize) -> CGRect {
        guard area.width > 0, area.height > 0 else { return .zero }
        let areaAspect = area.width / area.height
        let size: CGSize = areaAspect > mapAspect
            ? CGSize(width: area.height * mapAspect, height: area.height)
            : CGSize(width: area.width, height: area.width / mapAspect)
        return CGRect(
            x: (area.width - size.width) / 2,
            y: (area.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    var body: some View {
        ZStack {
            FlatMap.oceanColor

            Image("MyosiaMap")
                .resizable()
                .frame(width: imageRect.width, height: imageRect.height)
                .position(x: imageRect.midX, y: imageRect.midY)
        }
    }
}

/// A radial from a tuned VOR: `origin` is the station's on-screen point and
/// `courseDegrees` is the selected OBS course (0 = north, clockwise).
struct Radial: Identifiable {
    let id = UUID()
    let origin: CGPoint
    let courseDegrees: Double
}

/// Draws each tuned radial as a solid green line along the selected course and a
/// dashed red line along its 180° reciprocal, both emanating from the station.
struct RadialsOverlay: View {
    let radials: [Radial]
    /// How far each line extends from the station (large enough to cross the map).
    let length: CGFloat

    var body: some View {
        Canvas { context, _ in
            for radial in radials {
                let radians = radial.courseDegrees * .pi / 180
                // Screen vector for a bearing: 0° = up, increasing clockwise.
                let dx = sin(radians), dy = -cos(radians)
                let selectedEnd = CGPoint(x: radial.origin.x + dx * length,
                                          y: radial.origin.y + dy * length)
                let reciprocalEnd = CGPoint(x: radial.origin.x - dx * length,
                                            y: radial.origin.y - dy * length)

                var selected = Path()
                selected.move(to: radial.origin)
                selected.addLine(to: selectedEnd)
                context.stroke(selected, with: .color(.green), lineWidth: 1)

                var reciprocal = Path()
                reciprocal.move(to: radial.origin)
                reciprocal.addLine(to: reciprocalEnd)
                context.stroke(reciprocal, with: .color(.red),
                               style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            }
        }
    }
}

/// A VOR station marker with optional details labelled beneath it.
struct VORStationView: View {
    let station: VORStation
    let isSelected: Bool

    var body: some View {
        // The symbol is the positioned view, so its center (the station's dot) sits
        // exactly on the map anchor — and radial lines originate there. The label
        // floats below as an overlay so it doesn't shift that center.
        VORSymbol(type: station.type, size: 38)
            .overlay(alignment: .top) {
                if isSelected {
                    VStack(spacing: 2) {
                        Text(station.name)
                        Text("\(station.ident) - \(station.frequencyLabel)")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 5))
                    .fixedSize()
                    .offset(y: 42)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(VORHexagon())
    }
}

/// A selected station's service volume, drawn in map space and scaled with the
/// map camera so the ring stays aligned with the station's real coverage area.
struct VORServiceRangeRing: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .stroke(.red.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 4]))
            .frame(width: radius * 2, height: radius * 2)
            .allowsHitTesting(false)
    }
}

/// A compact compass rose shown around a selected VOR at higher zoom levels.
struct CompassRoseView: View {
    private let radius: CGFloat = 82
    private let canvasPadding: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerRadius = radius

            var outerCircle = Path()
            outerCircle.addEllipse(in: CGRect(x: center.x - outerRadius,
                                               y: center.y - outerRadius,
                                               width: outerRadius * 2,
                                               height: outerRadius * 2))
            context.stroke(outerCircle, with: .color(.white.opacity(0.8)), lineWidth: 1)

            for degrees in stride(from: 0, to: 360, by: 10) {
                let isLabelled = degrees % 30 == 0
                let angle = Double(degrees) * .pi / 180 - .pi / 2
                let innerRadius = outerRadius - (isLabelled ? 13 : 7)
                let inner = CGPoint(x: center.x + cos(angle) * innerRadius,
                                     y: center.y + sin(angle) * innerRadius)
                let outer = CGPoint(x: center.x + cos(angle) * outerRadius,
                                    y: center.y + sin(angle) * outerRadius)

                var tick = Path()
                tick.move(to: inner)
                tick.addLine(to: outer)
                context.stroke(tick,
                               with: .color(.white.opacity(isLabelled ? 0.95 : 0.75)),
                               lineWidth: isLabelled ? 1.5 : 1)

                if isLabelled {
                    let labelRadius = outerRadius + 11
                    let labelPoint = CGPoint(x: center.x + cos(angle) * labelRadius,
                                             y: center.y + sin(angle) * labelRadius)
                    let labelValue = degrees == 0 ? 36 : degrees / 10
                    let label = Text(String(format: "%02d", labelValue))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    context.draw(context.resolve(label), at: labelPoint, anchor: .center)
                }
            }
        }
        .frame(width: radius * 2 + canvasPadding * 2,
               height: radius * 2 + canvasPadding * 2)
        .shadow(color: .black.opacity(0.8), radius: 2)
        .allowsHitTesting(false)
    }
}

/// The standard aeronautical-chart symbol for a navaid, drawn as vectors:
/// a flat-top hexagon with a center dot (VOR), enclosed in a square (VOR-DME),
/// or with three filled TACAN tabs on its outer edges (VORTAC).
struct VORSymbol: View {
    let type: VORType
    var size: CGFloat = 38
    var color: Color = .black

    var body: some View {
        let lineWidth = size * 0.04
        ZStack {
            if type == .vortac {
                TacanTabs().fill(color)
            }
            if type == .vorDME {
                DMESquare().stroke(color, lineWidth: lineWidth)
            }
            VORHexagon().stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
            Circle()
                .fill(color)
                .frame(width: size * 0.1, height: size * 0.1)
        }
        .frame(width: size, height: size)
        // A soft light halo so the black symbol reads on both light and dark terrain.
        .shadow(color: .white.opacity(0.9), radius: 1)
    }
}

/// Shared geometry for the navaid symbols: a wide flat-top hexagon (points on the
/// left and right, ~1.15× wider than tall), matching the aeronautical chart symbol.
enum VORGeometry {
    static let halfW: CGFloat = 0.30     // hexagon half-width, fraction of the frame
    static let aspect: CGFloat = 1.157   // hexagon width / height
    static let tabDepth: CGFloat = 0.16  // TACAN tab extrusion, fraction of the frame
    static let squarePad: CGFloat = 0.03 // VOR-DME square inset beyond the hex top/bottom

    /// The six hexagon vertices, in the coordinate space of `rect`.
    static func vertices(in rect: CGRect) -> (topLeft: CGPoint, topRight: CGPoint, right: CGPoint,
                                              bottomRight: CGPoint, bottomLeft: CGPoint, left: CGPoint) {
        let halfH = halfW / aspect
        let topHalf = halfW * 0.5
        func p(_ nx: CGFloat, _ ny: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + nx * rect.width, y: rect.minY + ny * rect.height)
        }
        return (
            topLeft: p(0.5 - topHalf, 0.5 - halfH),
            topRight: p(0.5 + topHalf, 0.5 - halfH),
            right: p(0.5 + halfW, 0.5),
            bottomRight: p(0.5 + topHalf, 0.5 + halfH),
            bottomLeft: p(0.5 - topHalf, 0.5 + halfH),
            left: p(0.5 - halfW, 0.5)
        )
    }
}

/// The flat-top VOR hexagon outline.
struct VORHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let v = VORGeometry.vertices(in: rect)
        var path = Path()
        // List every edge explicitly (including the closing upper-left edge back to
        // topLeft) so all six sides are stroked — relying on closeSubpath() alone
        // leaves that closing edge undrawn when stroking.
        path.addLines([v.topLeft, v.topRight, v.right, v.bottomRight, v.bottomLeft, v.left, v.topLeft])
        path.closeSubpath()
        return path
    }
}

/// The VOR-DME square whose left/right sides meet the hexagon's side points.
struct DMESquare: Shape {
    func path(in rect: CGRect) -> Path {
        let halfW = VORGeometry.halfW
        let halfH = halfW / VORGeometry.aspect
        let pad = VORGeometry.squarePad
        return Path(CGRect(
            x: rect.minX + (0.5 - halfW) * rect.width,
            y: rect.minY + (0.5 - halfH - pad) * rect.height,
            width: 2 * halfW * rect.width,
            height: (2 * halfH + 2 * pad) * rect.height
        ))
    }
}

/// The three filled TACAN tabs of a VORTAC, spanning the upper-left, upper-right,
/// and bottom hexagon edges and extruded outward.
struct TacanTabs: Shape {
    func path(in rect: CGRect) -> Path {
        let v = VORGeometry.vertices(in: rect)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let depth = VORGeometry.tabDepth * rect.width
        var path = Path()
        for (a, b) in [(v.left, v.topLeft), (v.topRight, v.right), (v.bottomRight, v.bottomLeft)] {
            path.addPath(tab(from: a, to: b, awayFrom: center, depth: depth))
        }
        return path
    }

    /// A filled quadrilateral covering most of edge A→B, extruded outward from `pivot`.
    private func tab(from a: CGPoint, to b: CGPoint, awayFrom pivot: CGPoint, depth: CGFloat) -> Path {
        let ux = b.x - a.x, uy = b.y - a.y
        let len = max(hypot(ux, uy), 0.0001)
        let u = CGPoint(x: ux / len, y: uy / len)
        var n = CGPoint(x: -u.y, y: u.x)
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        if n.x * (pivot.x - mid.x) + n.y * (pivot.y - mid.y) > 0 {
            n = CGPoint(x: -n.x, y: -n.y)
        }
        let half = len * 0.42
        let p1 = CGPoint(x: mid.x - u.x * half, y: mid.y - u.y * half)
        let p2 = CGPoint(x: mid.x + u.x * half, y: mid.y + u.y * half)
        let p3 = CGPoint(x: p2.x + n.x * depth, y: p2.y + n.y * depth)
        let p4 = CGPoint(x: p1.x + n.x * depth, y: p1.y + n.y * depth)
        var path = Path()
        // Enumerate all four corners explicitly (back to p1); relying on
        // closeSubpath() drops the p4→p1 edge and fills only a triangle.
        path.addLines([p1, p2, p3, p4, p1])
        path.closeSubpath()
        return path
    }
}

/// An airport icon that shows a popover with name and ICAO code on tap.
struct AirportMarkerView: View {
    let airport: Airport
    @State private var showPopover = false

    var body: some View {
        Group {
            if airport.size == .large {
                LargeAirportIcon(size: 35)
            } else {
                SmallAirportIcon(size: 26)
            }
        }
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(airport.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(airport.icao)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(airport.size == .large ? "Major Airport" : "Local Airfield")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(red: 0.13, green: 0.14, blue: 0.17))
        }
    }
}

/// The base burgundy color for airports, sampled from reference.
private let airportBurgundy = Color(red: 149/255, green: 33/255, blue: 71/255)

/// Small airport icon: burgundy circle with diagonal runway.
struct SmallAirportIcon: View {
    var size: CGFloat = 42
    var body: some View {
        ZStack {
            Circle()
                .fill(airportBurgundy)
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color.white)
                .frame(width: size * 0.16, height: size * 0.72)
                .rotationEffect(.degrees(-25))
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.7), radius: 1)
    }
}

/// Large airport icon: burgundy circle with two white crossed runways (X).
struct LargeAirportIcon: View {
    var size: CGFloat = 52
    var body: some View {
        ZStack {
            Circle()
                .fill(airportBurgundy)
            // First runway (diagonal)
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color.white)
                .frame(width: size * 0.16, height: size * 0.75)
                .rotationEffect(.degrees(-25))
            // Second runway (crossed)
            RoundedRectangle(cornerRadius: size * 0.1)
                .fill(Color.white)
                .frame(width: size * 0.16, height: size * 0.65)
                .rotationEffect(.degrees(55))
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.7), radius: 1)
    }
}

/// The player's plane icon, rotated to face its current heading.
struct PlaneIcon: View {
    /// Heading in degrees (0 = north/up, increasing clockwise).
    var heading: Double = 0

    var body: some View {
        Image(systemName: "airplane")
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .foregroundStyle(.yellow)
            // The SF Symbol's nose points east by default; −90° aligns it to north
            // at heading 0, then it rotates with the heading.
            .rotationEffect(.degrees(heading - 90))
            .shadow(radius: 4)
    }
}

#Preview("VOR symbols") {
    VStack(spacing: 24) {
        ForEach([VORType.vor, .vorDME, .vortac], id: \.rawValue) { type in
            HStack(spacing: 20) {
                VORSymbol(type: type, size: 90)
                Text(type.rawValue).font(.title2.monospaced())
            }
        }
    }
    .padding(40)
    .background(Color(red: 0.72, green: 0.76, blue: 0.55))
}

#Preview("Airport icons") {
    HStack(spacing: 32) {
        SmallAirportIcon(size: 60)
        LargeAirportIcon(size: 80)
    }
    .padding(40)
    .background(Color.white)
}
