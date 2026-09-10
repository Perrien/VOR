import Foundation
import CoreGraphics

/// The kind of navaid a station is.
enum VORType: String, Decodable {
    case vor = "VOR"
    case vorDME = "VOR_DME"
    case vortac = "VORTAC"
}

/// The standard service volume assigned to a VOR station.
enum VORServiceVolume: String, Decodable, CaseIterable, Hashable {
    case high = "H"
    case low = "L"
    case terminal = "T"

    /// Human-readable category label used by the map layer controls.
    var displayName: String {
        switch self {
        case .high: return "High"
        case .low: return "Low"
        case .terminal: return "Terminal"
        }
    }

    /// Maximum reception distance for this service volume, in nautical miles.
    var rangeNM: Double {
        switch self {
        case .low: return 40
        case .high: return 100
        case .terminal: return 25
        }
    }
}

/// A single VOR ground station on the map, decoded from `VORStations.json`.
struct VORStation: Identifiable, Decodable {
    /// A map coordinate, each component in 0...1 relative to the map image.
    struct Location: Decodable {
        let x: Double
        let y: Double
    }

    /// Internal unique ID used by the app.
    let id: String
    /// Full station name, e.g. "Central".
    let name: String
    /// Three-letter VOR identifier displayed to the user, e.g. "CTR".
    let identifier: String
    /// NAV frequency in MHz.
    let frequency: Double
    /// Position relative to the map image (each component 0...1), on the land of Myosia.
    let location: Location
    /// Station kind: VOR, VOR_DME, VORTAC, etc.
    let type: VORType
    /// General station coverage classification.
    let serviceVolume: VORServiceVolume
    /// Station elevation, in feet.
    let elevationFT: Double
    /// Whether DME is available.
    let dme: Bool

    /// Maximum reception distance derived from the station's service volume.
    var rangeNM: Double { serviceVolume.rangeNM }

    /// The identifier, exposed under the shorter name the UI uses.
    var ident: String { identifier }

    /// The station's position as a point in the map's 0...1 space.
    var relativePosition: CGPoint { CGPoint(x: location.x, y: location.y) }

    /// The frequency formatted for display, e.g. "114.30".
    var frequencyLabel: String {
        String(format: "%.2f", frequency)
    }

    /// The fixed network of VOR beacons on the continent of Myosia, loaded from
    /// the bundled `VORStations.json`.
    static let myosia: [VORStation] = loadFromBundle()

    /// Decodes the station list from the app bundle. A malformed or missing file
    /// is a build-time authoring error, so we trap it loudly in debug builds.
    private static func loadFromBundle() -> [VORStation] {
        guard let url = Bundle.main.url(forResource: "VORStations", withExtension: "json") else {
            assertionFailure("VORStations.json is missing from the app bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([VORStation].self, from: data)
        } catch {
            assertionFailure("Failed to decode VORStations.json: \(error)")
            return []
        }
    }
}

enum AirportSize: String, Decodable {
    case large, small
}

/// An airport on the map, decoded from `Airports.json`.
struct Airport: Identifiable, Decodable {
    /// Unique ID.
    let id = UUID()
    /// Airport full name.
    let name: String
    /// ICAO code.
    let icao: String
    /// Whether this is a large international/regional or small local airport.
    let size: AirportSize
    /// X position, 0...1 relative to the map image (left → right).
    let x: Double
    /// Y position, 0...1 relative to the map image (top → bottom).
    let y: Double

    private enum CodingKeys: String, CodingKey {
        case name, icao, size, x, y
    }

    /// Returns the screen position within the given fitted image rect.
    func normalizedPosition(in imageRect: CGRect) -> CGPoint {
        CGPoint(x: imageRect.minX + CGFloat(x) * imageRect.width,
                y: imageRect.minY + CGFloat(y) * imageRect.height)
    }
    
    /// Loads airports from the bundled Airports.json file.
    static func loadFromBundle() -> [Airport] {
        guard let url = Bundle.main.url(forResource: "Airports", withExtension: "json") else {
            assertionFailure("Airports.json is missing from the bundle.")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Airport].self, from: data)
        } catch {
            assertionFailure("Failed to decode Airports.json: \(error)")
            return []
        }
    }
}

/// The state a CDI displays: which way the needle deflects and the TO/FROM flag.
struct CDIReading {
    enum Flag { case to, from, off }

    /// Needle deflection, −1 (full left) … +1 (full right). 0 = on course.
    let deflection: Double
    let flag: Flag

    static let off = CDIReading(deflection: 0, flag: .off)
}
