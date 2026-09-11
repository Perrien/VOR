import SwiftUI

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
    private let diameter: CGFloat = 150
    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        HStack(spacing: 14) {
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

                Spacer(minLength: 0)
            }

            ZStack {
                HeadingIndicator(heading: heading, diameter: diameter)

                // Turn buttons tucked into the lower corners of the dial, echoing
                // the OBS knob's placement on the NAV instruments.
                HoldTurnButton(systemImage: "arrow.counterclockwise") { dt in
                    turn(by: -turnRate * dt)
                }
                .offset(x: -radius + 6, y: radius - 6)

                HoldTurnButton(systemImage: "arrow.clockwise") { dt in
                    turn(by: turnRate * dt)
                }
                .offset(x: radius - 6, y: radius - 6)
            }

            VStack(alignment: .leading, spacing: 8) {
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
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// A directional-gyro style heading indicator: a rotating compass card with a
/// fixed plane silhouette and a top index showing the current heading.
struct HeadingIndicator: View {
    let heading: Double
    var diameter: CGFloat = 150

    private var radius: CGFloat { diameter / 2 }

    var body: some View {
        ZStack {
            // Bezel.
            Circle()
                .fill(Color.black)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 2))

            // Compass card rotates so the current heading sits under the top index.
            CompassCard(radius: radius)
                .rotationEffect(.degrees(-heading))

            // Fixed plane silhouette, always pointing "up" (toward the index).
            // The airplane symbol points east by default, so −90° faces it up.
            Image(systemName: "airplane")
                .font(.system(size: 26))
                .foregroundStyle(.yellow)
                .rotationEffect(.degrees(-90))

            // Fixed heading index at the top (the lubber line).
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 16))
                .offset(y: -radius + 10)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// A round button that repeatedly invokes `onTick` while held down, passing the
/// elapsed time (seconds) since the last tick so callers can turn at a steady rate.
struct HoldTurnButton: View {
    let systemImage: String
    let onTick: (Double) -> Void

    @State private var task: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
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
    /// The beacon the typed identifier resolves to, or `nil` if none matches.
    let tunedStation: VORStation?
    /// Resolves the CDI reading for a given OBS setting.
    let reading: (Double) -> CDIReading

    private var isTuned: Bool { tunedStation != nil }

    var body: some View {
        HStack(spacing: 14) {
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

            OBSInstrument(obs: $obs, reading: reading(obs), diameter: 150)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ControlPalette.cardBackground, in: RoundedRectangle(cornerRadius: 10))
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
    private var maxDeflection: CGFloat { radius * 0.6 }

    var body: some View {
        ZStack {
            // Bezel.
            Circle()
                .fill(Color.black)
                .overlay(Circle().stroke(Color.gray.opacity(0.6), lineWidth: 2))

            // Rotating compass card.
            CompassCard(radius: radius)
                .rotationEffect(.degrees(-obs))

            // Fixed instrument face: deviation scale, needle, TO/FROM.
            deviationScale
            if reading.flag != .off {
                cdiNeedle
                toFromIndicator
            } else {
                navFlag
            }

            // Fixed course index at the top.
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 16))
                .offset(y: -radius + 10)

            // OBS knob (decorative — the whole dial is draggable).
            Text("OBS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.4), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                .offset(x: -radius + 4, y: radius - 4)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(rotationDrag)
    }

    // MARK: Fixed overlay pieces

    /// The horizontal row of deviation dots the needle is read against.
    private var deviationScale: some View {
        HStack(spacing: (maxDeflection - 6) / 2) {
            ForEach(-2...2, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.7), lineWidth: index == 0 ? 0 : 1.5)
                    .background(index == 0 ? Circle().stroke(.white, lineWidth: 1.5) : nil)
                    .frame(width: index == 0 ? 14 : 8, height: index == 0 ? 14 : 8)
            }
        }
    }

    /// The vertical CDI needle, offset horizontally by the deflection.
    private var cdiNeedle: some View {
        Capsule()
            .fill(.yellow)
            .frame(width: 4, height: diameter * 0.62)
            .offset(x: CGFloat(reading.deflection) * maxDeflection)
            .animation(.easeOut(duration: 0.15), value: reading.deflection)
    }

    /// The TO or FROM triangle, whichever is active.
    private var toFromIndicator: some View {
        Group {
            if reading.flag == .to {
                Image(systemName: "arrowtriangle.up.fill")
                    .foregroundStyle(.white)
                    .offset(y: -radius * 0.42)
            } else if reading.flag == .from {
                Image(systemName: "arrowtriangle.down.fill")
                    .foregroundStyle(.white)
                    .offset(y: radius * 0.42)
            }
        }
        .font(.system(size: 15))
    }

    /// Shown when no valid station is tuned — the "unreliable signal" flag.
    private var navFlag: some View {
        Text("NAV")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.red, in: RoundedRectangle(cornerRadius: 3))
            .offset(x: radius * 0.32, y: -radius * 0.32)
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

/// The rotating compass card: tick marks every 10° and headings every 30°.
struct CompassCard: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Tick marks.
            ForEach(0..<36, id: \.self) { i in
                let isMajor = i % 3 == 0
                Rectangle()
                    .fill(.white)
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 7)
                    .offset(y: -radius + 8)
                    .rotationEffect(.degrees(Double(i) * 10))
            }

            // Heading numbers (N, 3, 6, E, 12, 15, S, 21, 24, W, 30, 33).
            ForEach(0..<12, id: \.self) { i in
                Text(label(for: i))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -radius + 28)
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
