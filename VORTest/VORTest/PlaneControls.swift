import SwiftUI

enum NavigationInstrumentStyle: String, CaseIterable, Identifiable {
    case cdi
    case hsi

    var id: Self { self }

    var displayName: String {
        switch self {
        case .cdi: return "CDI"
        case .hsi: return "HSI"
        }
    }
}

enum ControlPalette {
    static let panelBackground = Color(red: 0.88, green: 0.89, blue: 0.91)
    static let cardBackground = Color(red: 0.95, green: 0.96, blue: 0.97)
    static let fieldBackground = Color.white.opacity(0.82)
    static let primaryText = Color(red: 0.12, green: 0.14, blue: 0.16)
    static let secondaryText = Color(red: 0.32, green: 0.35, blue: 0.38)
    static let accent = Color(red: 0.00, green: 0.36, blue: 0.25)
    static let divider = Color.black.opacity(0.16)
    static let fieldBorder = Color.black.opacity(0.22)
}

// MARK: - Plane Controls
/// The plane control panel: a heading indicator flanked by press-and-hold turn
/// buttons. Holding a button rotates the plane continuously; the readout and the
/// plane icon on the map both follow `heading`.
struct PlaneControlView: View {
    @Binding var heading: Double
    @Binding var speedKnots: Double
    @Binding var isFlying: Bool

    @State private var speedText: String = ""

    // How fast the turn buttons rotate the plane, in degrees per second.
    private let turnRate: Double = 10
    private let cardPadding: CGFloat = 12
    private let contentSpacing: CGFloat = 14
    private let headingReadoutWidth: CGFloat = 50
    private let speedControlsWidth: CGFloat = 104

    var body: some View {
        GeometryReader { geometry in
            let diameter = dialDiameter(in: geometry.size)
            let radius = diameter / 2
            let turnButtonSize = diameter * (34 / 150)
            let turnButtonInset = diameter * (6 / 150)

            HStack(spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PLANE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ControlPalette.accent)

                    Text("HDG")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ControlPalette.accent)

                    Text(String(format: "%03d°", displayHeading))
                        .font(.title2.monospacedDigit().weight(.medium))
                        .foregroundStyle(ControlPalette.accent)
                        .lineLimit(1)
                        .fixedSize()

                    //Spacer(minLength: 0)

                    Text("SPEED")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ControlPalette.secondaryText)

                    HStack(spacing: 4) {
                        TextField("120", text: $speedText)
                            .textFieldStyle(.plain)
                            .font(.title2.monospacedDigit().weight(.medium))
                            .foregroundStyle(ControlPalette.accent)
                            .frame(width: 62)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(ControlPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(ControlPalette.fieldBorder, lineWidth: 1)
                            )

                        Text("KTS")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(ControlPalette.secondaryText)
                    }

                    Button {
                        isFlying.toggle()
                    } label: {
                        Label(isFlying ? "Pause" : "Play",
                              systemImage: isFlying ? "pause.fill" : "play.fill")
                            .frame(minWidth: 82)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isFlying ? .orange : .green)
                    .keyboardShortcut(.space, modifiers: [])
                }
                .frame(width: speedControlsWidth, alignment: .leading)

                if diameter > 0 {
                    ZStack {
                        HeadingIndicator(heading: heading, diameter: diameter)

                        // Turn buttons tuck into the lower corners of the dial.
                        HoldTurnButton(systemImage: "arrow.counterclockwise", size: turnButtonSize) { dt in
                            turn(by: -turnRate * dt)
                        }
                        .offset(x: -radius + turnButtonInset, y: radius - turnButtonInset)

                        HoldTurnButton(systemImage: "arrow.clockwise", size: turnButtonSize) { dt in
                            turn(by: turnRate * dt)
                        }
                        .offset(x: radius - turnButtonInset, y: radius - turnButtonInset)
                    }
                }

            }
            .padding(cardPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ControlPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .onAppear {
            speedText = formattedSpeed(speedKnots)
        }
        .onChange(of: speedText) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                speedText = filtered
            }
            if let speed = Double(filtered) {
                speedKnots = max(0, speed)
            }
        }
        .onSubmit {
            speedText = formattedSpeed(speedKnots)
        }
    }

    /// Uses the smaller of the usable card height and the horizontal room left
    /// after the heading and speed controls. This lets the dial follow panel
    /// resizing without overlapping either control column.
    private func dialDiameter(in cardSize: CGSize) -> CGFloat {
        let usableHeight = max(0, cardSize.height - cardPadding * 2)
        let usableWidth = max(0, cardSize.width - cardPadding * 2)
        let widthForDial = max(0, usableWidth - headingReadoutWidth - speedControlsWidth - contentSpacing * 2)
        return min(usableHeight, widthForDial)
    }

    /// The heading rounded to whole degrees for display (360 instead of 0).
    private var displayHeading: Int {
        let rounded = Int(heading.rounded()) % 360
        return rounded == 0 ? 360 : rounded
    }

    /// Rotates the plane by `delta` degrees, wrapping into 0..<360.
    private func turn(by delta: Double) {
        var next = (heading + delta).truncatingRemainder(dividingBy: 360)
        if next < 0 { next += 360 }
        heading = next
    }

    private func formattedSpeed(_ speed: Double) -> String {
        String(format: "%.0f", speed)
    }
}

// MARK: - Heading Indicator
/// A directional-gyro style heading indicator: a rotating compass card with a
/// fixed plane silhouette and a top index showing the current heading.
struct HeadingIndicator: View {
    let heading: Double
    var diameter: CGFloat = 150

    private var radius: CGFloat { diameter / 2 }
    private var scale: CGFloat { diameter / 150 }

    var body: some View {
        ZStack {
            // Bezel.
            Circle()
                .fill(Color.black)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 2 * scale))

            // Compass card rotates so the current heading sits under the top index.
            CompassCard(radius: radius)
                .rotationEffect(.degrees(-heading))

            // Fixed plane silhouette, always pointing "up" (toward the index).
            // The airplane symbol points east by default, so −90° faces it up.
            Image(systemName: "airplane")
                .font(.system(size: 50 * scale))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-90))

            // Fixed heading index at the top (the lubber line).
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 16 * scale))
                .offset(y: -radius + 10 * scale)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A round button that repeatedly invokes `onTick` while held down, passing the
/// elapsed time (seconds) since the last tick so callers can turn at a steady rate.
struct HoldTurnButton: View {
    let systemImage: String
    var size: CGFloat = 34
    let onTick: (Double) -> Void

    @State private var task: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.orange, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if task == nil { startTurning() } }
                    .onEnded { _ in stopTurning() }
            )
    }

    private func startTurning() {
        task = Task { @MainActor in
            let dt = 1.0 / 60.0
            while !Task.isCancelled {
                onTick(dt)
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    private func stopTurning() {
        task?.cancel()
        task = nil
    }
}

// MARK: - Radios

/// A single tunable NAV radio paired with its OBS/CDI instrument.
///
/// Tuning is done by typing a station identifier (e.g. "CTR"); when it matches a
/// beacon, the radio locks on and shows the station's frequency as confirmation.
struct NavRadioView: View {
    let name: String
    @Binding var ident: String
    @Binding var obs: Double
    let heading: Double
    let instrumentStyle: NavigationInstrumentStyle
    /// The beacon the typed identifier resolves to, or `nil` if none matches.
    let tunedStation: VORStation?
    /// Resolves the CDI reading for a given OBS setting.
    let reading: (Double) -> CDIReading

    private var isTuned: Bool { tunedStation != nil }
    private let cardPadding: CGFloat = 12
    private let contentSpacing: CGFloat = 14
    private let radioDetailsWidth: CGFloat = 104

    var body: some View {
        GeometryReader { geometry in
            let diameter = dialDiameter(in: geometry.size)

            HStack(spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ControlPalette.secondaryText)

                    Text("IDENT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ControlPalette.secondaryText)

                    TextField("---", text: identText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced().weight(.semibold))
                        .foregroundStyle(ControlPalette.accent)
                        .frame(width: 88)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ControlPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isTuned ? ControlPalette.accent.opacity(0.7) : ControlPalette.fieldBorder, lineWidth: 1)
                        )

                    Text(tunedStation.map { "\($0.frequencyLabel) MHz" } ?? "--- MHz")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isTuned ? ControlPalette.accent : ControlPalette.secondaryText)

                    Label(isTuned ? "Station tuned" : "No station",
                          systemImage: isTuned ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.caption2)
                        .foregroundStyle(isTuned ? Color(red: 0.00, green: 0.38, blue: 0.48) : ControlPalette.secondaryText)

                    Text(String(format: "CRS %03d°", displayCourse))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ControlPalette.primaryText)

                    Spacer(minLength: 0)
                }
                .frame(width: radioDetailsWidth, alignment: .leading)

                if diameter > 0 {
                    switch instrumentStyle {
                    case .cdi:
                        OBSInstrument(obs: $obs, reading: reading(obs), diameter: diameter)
                    case .hsi:
                        HSIInstrument(heading: heading, obs: $obs, reading: reading(obs), diameter: diameter)
                    }
                }
            }
            .padding(cardPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ControlPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    /// The CDI uses every point of vertical space that its card permits, capped
    /// by the width remaining after the tuned-station details.
    private func dialDiameter(in cardSize: CGSize) -> CGFloat {
        let usableHeight = max(0, cardSize.height - cardPadding * 2)
        let usableWidth = max(0, cardSize.width - cardPadding * 2)
        let widthForDial = max(0, usableWidth - radioDetailsWidth - contentSpacing)
        return min(usableHeight, widthForDial)
    }

    /// The OBS course rounded to whole degrees for display (360 instead of 0).
    private var displayCourse: Int {
        let rounded = Int(obs.rounded()) % 360
        return rounded == 0 ? 360 : rounded
    }

    /// A proxy that normalizes typed identifiers: uppercased and capped at the
    /// three characters a VOR ident uses.
    private var identText: Binding<String> {
        Binding(
            get: { ident },
            set: { ident = String($0.uppercased().prefix(3)) }
        )
    }

}

/// Edits the angular deviation represented by full-scale CDI deflection.
struct CDIMaxField: View {
    @Binding var value: Double
    @State private var text: String = ""

    private var isValid: Bool {
        guard let number = Double(text) else { return false }
        return number > 0 && number < 90
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CDI max")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ControlPalette.primaryText)

            HStack(spacing: 8) {
                TextField("10", text: $text)
                    .textFieldStyle(.plain)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ControlPalette.primaryText)
                    .frame(width: 42)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(ControlPalette.fieldBackground, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isValid ? ControlPalette.fieldBorder : Color.red.opacity(0.8), lineWidth: 1)
                        )

                Text("degrees")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ControlPalette.primaryText)
            }

            Text("Enter a value greater than 0 and less than 90")
                .font(.caption2)
                .foregroundStyle(isValid ? ControlPalette.secondaryText : Color.red)
        }
        .onAppear {
            text = formatted(value)
        }
        .onChange(of: text) { _, newValue in
            let filtered = sanitized(newValue)
            if filtered != newValue {
                text = filtered
                return
            }

            if let number = Double(filtered), number > 0, number < 90 {
                value = number
            }
        }
        .onSubmit {
            text = formatted(value)
        }
    }

    private func sanitized(_ input: String) -> String {
        var output = ""
        var hasDecimal = false

        for character in input {
            if character.isNumber {
                output.append(character)
            } else if character == "." && !hasDecimal {
                output.append(character)
                hasDecimal = true
            }
        }

        return output
    }

    private func formatted(_ number: Double) -> String {
        number.rounded() == number ? String(format: "%.0f", number) : String(format: "%.2f", number)
    }
}

// MARK: - OBS / CDI instrument

/// The OBS/CDI instrument: a draggable compass card, course index, CDI needle,
/// and TO/FROM flag. Dragging anywhere on the dial rotates the selected course.
struct OBSInstrument: View {
    @Binding var obs: Double
    let reading: CDIReading
    var diameter: CGFloat = 178

    // Tracks the previous drag angle so we can turn the dial like a knob.
    @State private var lastDragAngle: Double?

    private var radius: CGFloat { diameter / 2 }
    private var scale: CGFloat { diameter / 150 }
    /// The outer two CDI reference marks are full-scale deflection. Keeping the
    /// scale and needle tied to this value means the needle ends on a mark.
    private var fullScaleDeflection: CGFloat { diameter * 0.25 }
    private var cdiTickSpacing: CGFloat { fullScaleDeflection / 5 }
    /// The clear centre of the instrument. The CDI needle is clipped to this
    /// circle so a full-scale deflection cannot cross the compass card.
    private var cdiViewportDiameter: CGFloat { diameter * 0.60 }

    var body: some View {
        ZStack {
            // Bezel.
            Circle()
                .fill(Color.black)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 2 * scale))

            // Rotating compass card.
            CompassCard(radius: radius)
                .rotationEffect(.degrees(-obs))

            // Fixed instrument face: deviation scale, needle, TO/FROM.
            deviationScale
            if reading.flag != .off {
                maskedCDINeedle
            } else {
                navFlag
            }
            toFromIndicator

            // Fixed course index at the top.
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 14 * scale))
                .offset(y: -radius + 10 * scale)

            // OBS knob (decorative — the whole dial is draggable).
            /*Text("OBS")
                .font(.system(size: 9 * scale, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30 * scale, height: 30 * scale)
                .background(Color.gray.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: scale))
                .offset(x: -radius + 4 * scale, y: radius - 4 * scale)*/
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(rotationDrag)
    }

    // MARK: Fixed overlay pieces

    /// Five evenly spaced deviation marks. The end marks are full-scale CDI
    /// deflection, so the needle has a visible, reachable stop at each end.
    private var deviationScale: some View {
        ZStack {
            ForEach(-5...5, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == 0 ? 1 : 0.8))
                    .frame(width: (index == 0 ? 3 : 2) * scale,
                           height: (index == 0 ? 12 : 8) * scale)
                    .offset(x: CGFloat(index) * cdiTickSpacing)
            }
        }
        .frame(width: fullScaleDeflection * 2 + 8 * scale, height: 14 * scale)
    }

    /// The white CDI needle moves across the five marks and stops on either
    /// full-scale end mark.
    private var cdiNeedle: some View {
        let clampedDeflection = min(max(reading.deflection, -1), 1)

        return Capsule()
            .fill(.white)
            .frame(width: 3 * scale, height: cdiViewportDiameter)
            .offset(x: CGFloat(clampedDeflection) * fullScaleDeflection)
            .animation(.easeOut(duration: 0.15), value: reading.deflection)
    }

    /// Restricts the CDI needle to the centre of the instrument, without
    /// introducing a visible border or guide circle.
    private var maskedCDINeedle: some View {
        ZStack {
            cdiNeedle
        }
        .frame(width: cdiViewportDiameter, height: cdiViewportDiameter)
        .clipShape(Circle())
    }

    /// TO and FR remain in place on every state. Their separate placements
    /// mirror the upper and lower labels on the reference instrument.
    private var toFromIndicator: some View {
        let labelX = radius * 0.22
        let labelDistance = radius * 0.42
        let markerDistance = 14 * scale

        return ZStack {
            flagText("TO")
                .offset(x: labelX, y: -labelDistance)
            flagMarker(systemImage: "arrowtriangle.up.fill", isActive: reading.flag == .to)
                .offset(x: labelX, y: -labelDistance + markerDistance)

            flagMarker(systemImage: "arrowtriangle.down.fill", isActive: reading.flag == .from)
                .offset(x: labelX, y: labelDistance - markerDistance)
            flagText("FR")
                .offset(x: labelX, y: labelDistance)
        }
    }

    private func flagText(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 10 * scale, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
    }

    private func flagMarker(systemImage: String, isActive: Bool) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 16 * scale, weight: .bold))
            .foregroundStyle(.yellow)
            .opacity(isActive ? 1 : 0)
            .frame(width: 16 * scale, height: 16 * scale)
    }

    /// Shown when no valid station is tuned. It occupies the open upper-left
    /// portion of the face, leaving the TO/FR indication clear on the right.
    private var navFlag: some View {
        Text("NAV")
            .font(.system(size: 10 * scale, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 2 * scale)
            .padding(.vertical, scale)
            .background(.red, in: RoundedRectangle(cornerRadius: 3 * scale))
            .offset(x: -radius * 0.30, y: -radius * 0.27)
    }

    // MARK: Rotational drag

    private var rotationDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: radius, y: radius)
                let angle = atan2(value.location.y - center.y,
                                  value.location.x - center.x) * 180 / .pi
                if let last = lastDragAngle {
                    var delta = angle - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    var next = (obs + delta).truncatingRemainder(dividingBy: 360)
                    if next < 0 { next += 360 }
                    obs = next
                }
                lastDragAngle = angle
            }
            .onEnded { _ in lastDragAngle = nil }
    }
}

/// An HSI combines the plane heading with the selected VOR course. The yellow
/// course arrow shows the OBS setting. Its smaller companion changes between
/// the selected course and its reciprocal to show TO versus FROM.
struct HSIInstrument: View {
    let heading: Double
    @Binding var obs: Double
    let reading: CDIReading
    var diameter: CGFloat = 178

    @State private var lastDragAngle: Double?

    private var radius: CGFloat { diameter / 2 }
    private var scale: CGFloat { diameter / 150 }
    private var relativeCourse: Double { obs - heading }
    private var fullScaleDeflection: CGFloat { diameter * 0.20 }
    private var deviationTickSpacing: CGFloat { fullScaleDeflection / 5 }
    private var coursePointerExtent: CGFloat { radius * 0.60 }
    private var cdiBarLength: CGFloat { radius * 0.74 }
    private var coursePointerSegmentLength: CGFloat { coursePointerExtent - cdiBarLength / 2 }
    private var coursePointerSegmentOffset: CGFloat { (coursePointerExtent + cdiBarLength / 2) / 2 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 2 * scale))

            // The heading card rotates under the fixed top index. There is no
            // centre airplane symbol because the heading at the index supplies
            // the useful orientation information.
            CompassCard(radius: radius)
                .rotationEffect(.degrees(-heading))

            selectedCourseArrow

            if reading.flag == .off {
                navigationFlag
            } else {
                courseDeviation
                toFromArrow
            }

            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 14 * scale))
                .offset(y: -radius + 10 * scale)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(rotationDrag)
    }

    /// The long arrow always points along the OBS course. It has no connection
    /// to the plane heading, except that the heading card makes their angle
    /// relative to each other visible.
    private var selectedCourseArrow: some View {
        ZStack {
            Capsule()
                .fill(.yellow)
                .frame(width: 3 * scale, height: coursePointerSegmentLength)
                .offset(y: -coursePointerSegmentOffset)
            Capsule()
                .fill(.yellow)
                .frame(width: 3 * scale, height: coursePointerSegmentLength)
                .offset(y: coursePointerSegmentOffset)
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 18 * scale, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(y: -radius * 0.55)
        }
        .rotationEffect(.degrees(relativeCourse))
    }

    /// The dots are fixed to the selected course. The white bar slides sideways
    /// across them to show the same lateral CDI deflection as the CDI display.
    private var courseDeviation: some View {
        let deflection = min(max(reading.deflection, -1), 1)

        return ZStack {
            ForEach(-5...5, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(index == 0 ? 1 : 0.85))
                    //.frame(width: 3 * scale, height: 3 * scale)
                    .frame(width: (index == 0 ? 4 : 3) * scale, height: (index == 0 ? 4 : 3) * scale)
                    .offset(x: CGFloat(index) * deviationTickSpacing)
            }

            Capsule()
                .fill(.white)
                .frame(width: 3 * scale, height: cdiBarLength)
                .offset(x: CGFloat(deflection) * fullScaleDeflection)
                .animation(.easeOut(duration: 0.15), value: reading.deflection)
        }
        .rotationEffect(.degrees(relativeCourse))
    }

    /// A small triangle points toward the VOR on a TO indication and toward the
    /// reciprocal on a FROM indication. For example, OBS 350° plus FROM makes
    /// this pointer face 170°, while the large course arrow stays at 350°.
    private var toFromArrow: some View {
        let direction = reading.flag == .to ? relativeCourse : relativeCourse + 180

        return Image(systemName: "arrowtriangle.up.fill")
            .font(.system(size: 13 * scale, weight: .bold))
            .foregroundStyle(.yellow)
            .offset(y: -radius * 0.29)
            .rotationEffect(.degrees(direction))
    }

    private var navigationFlag: some View {
        Text("NAV")
            .font(.system(size: 10 * scale, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 3 * scale)
            .padding(.vertical, scale)
            .background(.red, in: RoundedRectangle(cornerRadius: 3 * scale))
    }

    private var rotationDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let center = CGPoint(x: radius, y: radius)
                let angle = atan2(value.location.y - center.y,
                                  value.location.x - center.x) * 180 / .pi
                if let last = lastDragAngle {
                    var delta = angle - last
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    var next = (obs + delta).truncatingRemainder(dividingBy: 360)
                    if next < 0 { next += 360 }
                    obs = next
                }
                lastDragAngle = angle
            }
            .onEnded { _ in lastDragAngle = nil }
    }
}

/// The rotating compass card: tick marks every 10° and headings every 30°.
struct CompassCard: View {
    let radius: CGFloat

    private var scale: CGFloat { radius / 75 }

    var body: some View {
        ZStack {
            // Tick marks.
            ForEach(0..<36, id: \.self) { i in
                let isMajor = i % 3 == 0
                Rectangle()
                    .fill(.white)
                    .frame(width: (isMajor ? 2 : 1) * scale,
                           height: (isMajor ? 10 : 5) * scale)
                    .offset(y: -radius + 7 * scale)
                    .rotationEffect(.degrees(Double(i) * 10))
            }

            // Heading numbers (N, 3, 6, E, 12, 15, S, 21, 24, W, 30, 33).
            ForEach(0..<12, id: \.self) { i in
                Text(label(for: i))
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -radius + 22 * scale)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
    }

    private func label(for index: Int) -> String {
        switch index * 30 {
        case 0: return "N"
        case 90: return "E"
        case 180: return "S"
        case 270: return "W"
        default: return String(index * 3)
        }
    }
}
