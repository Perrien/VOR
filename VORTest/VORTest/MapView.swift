import SwiftUI
import AppKit

/// A flat map with VOR stations and a draggable plane, plus NAV radios below it.
struct MapView: View {
    // The fixed VOR beacons on the land of Myosia.
    private let stations: [VORStation] = VORStation.myosia
    // The fixed list of airports loaded once.
    private let airports: [Airport] = Airport.loadFromBundle()

    // The plane's current position, in the coordinate space of the map.
    // `nil` until the view lays out, at which point we center the plane.
    @State private var planePosition: CGPoint?

    // The plane's position when the current drag began, used to compute the
    // running offset while dragging.
    @State private var dragStartPosition: CGPoint?

    // The station identifiers the two NAV radios are tuned to (e.g. "CTR").
    // Empty or unrecognized means no station is tuned.
    @State private var nav1Ident: String = ""
    @State private var nav2Ident: String = ""

    // The course selected on each radio's OBS (0–360°).
    @State private var nav1OBS: Double = 0
    @State private var nav2OBS: Double = 0

    // The plane's magnetic heading (0–360°, 0 = north/up).
    @State private var heading: Double = 0

    // Map camera: zoom factor and pan offset (in screen points, applied to the
    // scaled map content). `panStart` snapshots the offset when a pan begins.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panStart: CGSize?

    // Which object layers are visible.
    @State private var showVORs: Bool = true
    @State private var visibleVORServiceVolumes: Set<VORServiceVolume> = Set(VORServiceVolume.allCases)
    @State private var showAirports: Bool = true
    @State private var showRadials: Bool = true
    // The station whose map details are currently expanded.
    @State private var selectedVORID: String?

    private let panelHeight: CGFloat = 250
    private let controlPanelWidth: CGFloat = 240
    private let minZoom: CGFloat = 1
    private let maxZoom: CGFloat = 6
    /// The source map is authored at 500 NM across.
    private let mapWidthNM: Double = 500
    private let compassRoseMinZoom: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let mapSize = CGSize(width: max(0, geometry.size.width - controlPanelWidth),
                                 height: max(0, geometry.size.height - panelHeight))
            // The map image is letterboxed (aspect-fit) inside the map area, so
            // everything on the map is positioned relative to this fitted rect.
            let imageRect = FlatMap.fittedRect(in: mapSize)
            let planePos = planePosition ?? CGPoint(x: imageRect.midX, y: imageRect.midY)

            // Compute the normalized plane position relative to imageRect in 0...1
            let normalizedPlanePosition: CGPoint? = {
                guard imageRect.width > 0, imageRect.height > 0 else { return nil }
                guard let planePosition = planePosition else { return nil }
                let x = (planePosition.x - imageRect.minX) / imageRect.width
                let y = (planePosition.y - imageRect.minY) / imageRect.height
                guard (0...1).contains(x), (0...1).contains(y) else { return nil }
                return CGPoint(x: x, y: y)
            }()
            let nav1Station = receivedStation(forIdent: nav1Ident,
                                              planePos: planePos,
                                              imageRect: imageRect)
            let nav2Station = receivedStation(forIdent: nav2Ident,
                                              planePos: planePos,
                                              imageRect: imageRect)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    mapArea(mapSize: mapSize, imageRect: imageRect, planePos: planePos)

                    HStack(spacing: 16) {
                        PlaneControlView(heading: $heading)

                        NavRadioView(
                            name: "NAV1",
                            ident: $nav1Ident,
                            obs: $nav1OBS,
                            tunedStation: nav1Station,
                            reading: { obs in cdiReading(station: nav1Station, obs: obs, planePos: planePos, imageRect: imageRect) }
                        )
                        NavRadioView(
                            name: "NAV2",
                            ident: $nav2Ident,
                            obs: $nav2OBS,
                            tunedStation: nav2Station,
                            reading: { obs in cdiReading(station: nav2Station, obs: obs, planePos: planePos, imageRect: imageRect) }
                        )
                    }
                    .padding(16)
                    .frame(height: panelHeight)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.13))
                }

                MapControlPanel(zoom: $zoom, showVORs: $showVORs,
                                visibleVORServiceVolumes: $visibleVORServiceVolumes,
                                showAirports: $showAirports, showRadials: $showRadials,
                                zoomRange: minZoom...maxZoom,
                                planePosition: Binding(get: { normalizedPlanePosition }, set: { _ in }))
                    .frame(width: controlPanelWidth)
            }
            // Re-clamp the pan whenever the zoom changes (e.g. via the slider) so
            // the map never drifts off the visible area.
            .onChange(of: zoom) {
                pan = clampedPan(pan, zoom: zoom, mapSize: mapSize)
            }
        }
        .ignoresSafeArea()
    }

    /// The zoomable, pannable map. Only the artwork scales with the camera; the
    /// markers and plane keep a constant screen size and are positioned by applying
    /// the same zoom/pan transform to their map coordinates (`screenPoint`).
    private func mapArea(mapSize: CGSize, imageRect: CGRect, planePos: CGPoint) -> some View {
        ZStack {
            // Map artwork: this is the only layer that scales with zoom.
            FlatMap(imageRect: imageRect)
                .frame(width: mapSize.width, height: mapSize.height)
                .scaleEffect(zoom)
                .offset(pan)

            // Radial lines from tuned stations, drawn beneath the station symbols.
            if showRadials {
                RadialsOverlay(radials: tunedRadials(planePos: planePos, imageRect: imageRect, mapSize: mapSize),
                               length: max(mapSize.width, mapSize.height) * 3)
                    .allowsHitTesting(false)
            }

            // Marker layer: constant size, manually transformed to track the map.
            if showVORs {
                ForEach(stations) { station in
                    if visibleVORServiceVolumes.contains(station.serviceVolume) {
                        let stationPoint = point(for: station, in: imageRect)
                        let screenStationPoint = screenPoint(stationPoint, mapSize: mapSize)
                        let showsCompassRose = selectedVORID == station.id && zoom >= compassRoseMinZoom

                        if selectedVORID == station.id {
                            VORServiceRangeRing(radius: serviceRangeRadius(for: station, imageRect: imageRect) * zoom)
                                .position(screenStationPoint)
                        }

                        if showsCompassRose {
                            CompassRoseView()
                                .position(screenStationPoint)
                        }

                        VORStationView(station: station, isSelected: selectedVORID == station.id)
                            .position(screenStationPoint)
                            .onTapGesture {
                                selectedVORID = selectedVORID == station.id ? nil : station.id
                            }
                        }
                    }
            }

            if showAirports {
                ForEach(airports) { airport in
                    AirportMarkerView(airport: airport)
                        .position(screenPoint(airport.normalizedPosition(in: imageRect), mapSize: mapSize))
                }
            }

            PlaneIcon(heading: heading)
                .position(screenPoint(planePos, mapSize: mapSize))
                // The plane's own drag wins over panning when the drag starts on it.
                .highPriorityGesture(planeDrag(planePos: planePos, mapSize: mapSize))
        }
        .frame(width: mapSize.width, height: mapSize.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(panGesture(mapSize: mapSize))
        .coordinateSpace(name: mapSpace)
        .background(
            ScrollWheelReader { deltaY in
                applyZoomDelta(deltaY, mapSize: mapSize)
            }
        )
    }

    private let mapSpace = "mapArea"

    /// The radials to draw for the currently tuned radios, in screen space.
    private func tunedRadials(planePos: CGPoint, imageRect: CGRect, mapSize: CGSize) -> [Radial] {
        var result: [Radial] = []
        for (ident, obs) in [(nav1Ident, nav1OBS), (nav2Ident, nav2OBS)] {
            if let station = receivedStation(forIdent: ident, planePos: planePos, imageRect: imageRect) {
                let origin = screenPoint(point(for: station, in: imageRect), mapSize: mapSize)
                result.append(Radial(origin: origin, courseDegrees: obs))
            }
        }
        return result
    }

    /// Maps a point in unscaled map space to its on-screen position under the
    /// current camera, matching `.scaleEffect(zoom).offset(pan)` about the center.
    private func screenPoint(_ p: CGPoint, mapSize: CGSize) -> CGPoint {
        let cx = mapSize.width / 2, cy = mapSize.height / 2
        return CGPoint(
            x: (p.x - cx) * zoom + cx + pan.width,
            y: (p.y - cy) * zoom + cy + pan.height
        )
    }

    /// Dragging the plane moves it around the map. Translation arrives in the
    /// unscaled map space, so we divide by `zoom` to convert to map coordinates.
    private func planeDrag(planePos: CGPoint, mapSize: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .named(mapSpace))
            .onChanged { value in
                let start = dragStartPosition ?? planePos
                if dragStartPosition == nil { dragStartPosition = start }
                let proposed = CGPoint(
                    x: start.x + value.translation.width / zoom,
                    y: start.y + value.translation.height / zoom
                )
                planePosition = clamp(proposed, in: mapSize)
            }
            .onEnded { _ in dragStartPosition = nil }
    }

    /// Dragging the map background pans it (only meaningful when zoomed in).
    private func panGesture(mapSize: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .named(mapSpace))
            .onChanged { value in
                let start = panStart ?? pan
                if panStart == nil { panStart = start }
                let proposed = CGSize(width: start.width + value.translation.width,
                                      height: start.height + value.translation.height)
                pan = clampedPan(proposed, zoom: zoom, mapSize: mapSize)
            }
            .onEnded { _ in panStart = nil }
    }

    /// Keeps the plane's center within the bounds of the map.
    private func clamp(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }

    /// Limits the pan offset so the scaled map always covers the map area —
    /// you can never drag empty space into view. At zoom 1 the only valid pan is zero.
    private func clampedPan(_ proposed: CGSize, zoom: CGFloat, mapSize: CGSize) -> CGSize {
        let maxX = max(0, mapSize.width * (zoom - 1) / 2)
        let maxY = max(0, mapSize.height * (zoom - 1) / 2)
        return CGSize(width: min(max(proposed.width, -maxX), maxX),
                      height: min(max(proposed.height, -maxY), maxY))
    }

    /// Applies a scroll-wheel delta to the zoom, centered on the map. Positive
    /// delta (scroll up) zooms in. Pan is re-clamped by `onChange(of: zoom)`.
    private func applyZoomDelta(_ deltaY: CGFloat, mapSize: CGSize) {
        let factor = 1 + deltaY * 0.08
        zoom = min(max(zoom * factor, minZoom), maxZoom)
    }

    /// The station whose identifier matches `ident` (case-insensitive), if any.
    private func station(forIdent ident: String) -> VORStation? {
        let key = ident.trimmingCharacters(in: .whitespaces).uppercased()
        guard !key.isEmpty else { return nil }
        return stations.first { $0.ident == key }
    }

    /// The station the radio can currently receive. The identifier remains in
    /// the radio while out of range, so reception returns as soon as the plane
    /// crosses back into the station's service volume.
    private func receivedStation(forIdent ident: String, planePos: CGPoint, imageRect: CGRect) -> VORStation? {
        guard let station = station(forIdent: ident) else { return nil }
        let stationPoint = point(for: station, in: imageRect)
        let distance = distanceNM(from: planePos, to: stationPoint, imageRect: imageRect)
        return distance <= station.serviceVolume.rangeNM ? station : nil
    }

    /// Converts map-space pixels to nautical miles using the source chart's
    /// 500 NM width. Both points are unscaled map coordinates, so zoom does not
    /// change the simulated distance.
    private func distanceNM(from planePoint: CGPoint, to stationPoint: CGPoint, imageRect: CGRect) -> Double {
        guard imageRect.width > 0 else { return .infinity }
        let pixelsPerNM = imageRect.width / CGFloat(mapWidthNM)
        return hypot(Double(planePoint.x - stationPoint.x),
                     Double(planePoint.y - stationPoint.y)) / Double(pixelsPerNM)
    }

    /// Converts a station's service volume into an unscaled map-space radius.
    private func serviceRangeRadius(for station: VORStation, imageRect: CGRect) -> CGFloat {
        imageRect.width * CGFloat(station.rangeNM / mapWidthNM)
    }

    /// The screen position of a station within the fitted map image.
    private func point(for station: VORStation, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + station.relativePosition.x * rect.width,
            y: rect.minY + station.relativePosition.y * rect.height
        )
    }

    /// Computes the CDI needle deflection and TO/FROM flag for a radio tuned to
    /// `station` with the OBS set to `obs`, given the plane's position.
    private func cdiReading(station: VORStation?, obs: Double, planePos: CGPoint, imageRect: CGRect) -> CDIReading {
        guard let station else { return .off }

        let stationPoint = point(for: station, in: imageRect)
        // Vector from station to plane (screen space: +x east, +y south).
        let vx = planePos.x - stationPoint.x
        let vy = planePos.y - stationPoint.y

        // The radial the plane is on = bearing FROM the station (0° = north/up).
        var radial = atan2(vx, -vy) * 180 / .pi
        if radial < 0 { radial += 360 }

        // Difference between the plane's radial and the selected course.
        let diff = normalize180(radial - obs)
        let flag: CDIReading.Flag = abs(diff) <= 90 ? .from : .to

        // Angular deviation from the selected course line (0–90°), full scale at 10°.
        let deviationAngle = flag == .from ? abs(diff) : 180 - abs(diff)

        // Which side of the course line the plane sits on decides needle direction:
        // plane to the right of course → course is to the left → needle deflects left.
        let obsRad = obs * .pi / 180
        let planeIsRightOfCourse = (vx * cos(obsRad) + vy * sin(obsRad)) > 0
        let sign: Double = planeIsRightOfCourse ? -1 : 1

        let deflection = sign * min(deviationAngle, 10) / 10
        return CDIReading(deflection: deflection, flag: flag)
    }
}

/// Wraps an angle to the range −180…180.
private func normalize180(_ angle: Double) -> Double {
    var result = angle.truncatingRemainder(dividingBy: 360)
    if result > 180 { result -= 360 }
    if result < -180 { result += 360 }
    return result
}

// MARK: - Map control panel

/// The right-hand panel for controlling the map view: zoom and layer visibility.
struct MapControlPanel: View {
    @Binding var zoom: CGFloat
    @Binding var showVORs: Bool
    @Binding var visibleVORServiceVolumes: Set<VORServiceVolume>
    @Binding var showAirports: Bool
    @Binding var showRadials: Bool
    let zoomRange: ClosedRange<CGFloat>

    // Added optional planePosition binding to show normalized plane coordinates
    var planePosition: Binding<CGPoint?>?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Map")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Zoom")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f×", zoom))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white)
                }
                Slider(value: $zoom, in: zoomRange)
            }

            Divider().overlay(Color.white.opacity(0.12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Layers")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Toggle("VORs", isOn: $showVORs)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(VORServiceVolume.allCases, id: \.self) { serviceVolume in
                        Toggle(serviceVolume.displayName,
                               isOn: Binding(
                                get: { visibleVORServiceVolumes.contains(serviceVolume) },
                                set: { isVisible in
                                    if isVisible {
                                        visibleVORServiceVolumes.insert(serviceVolume)
                                    } else {
                                        visibleVORServiceVolumes.remove(serviceVolume)
                                    }
                                }
                               ))
                            .toggleStyle(.checkbox)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.leading, 18)
                Toggle("Airports", isOn: $showAirports)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(.white)
                Toggle("Radials", isOn: $showRadials)
                    .toggleStyle(.checkbox)
                    .foregroundStyle(.white)
            }
            
            // Insert the Plane position section here
            if let planePosition = planePosition {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plane position")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if let rel = planePosition.wrappedValue {
                        Text(String(format: "X: %.4f", rel.x))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                        Text(String(format: "Y: %.4f", rel.y))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                    } else {
                        Text("X: --")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Y: --")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 0.13, green: 0.14, blue: 0.17))
    }
}

/// Bridges macOS mouse scroll-wheel events into SwiftUI. There is no first-party
/// modifier for scroll-wheel input on a plain view, so we install a local event
/// monitor and report the vertical delta when the pointer is over this view.
struct ScrollWheelReader: NSViewRepresentable {
    /// Called with the vertical scroll delta (positive = scroll up).
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MonitorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? MonitorView)?.onScroll = onScroll
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard monitor == nil, window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }
                // Only handle scrolls that land over the map area.
                let frame = self.convert(self.bounds, to: nil)
                guard frame.contains(event.locationInWindow) else { return event }
                let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.02 : event.deltaY
                self.onScroll?(delta)
                return nil
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}

#Preview {
    MapView()
        .frame(width: 1100, height: 760)
}
