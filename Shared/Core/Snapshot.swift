import Foundation

/// The readings at one instant, flattened for anything that is not the
/// dashboard: the Live Activity, the widgets, and the watch when it mirrors
/// the phone. Metres, metres per second and hectopascals throughout — the
/// consumer converts, so the units travel with it.
struct Snapshot: Codable, Hashable, Sendable {
    var barometricAltitude: Double?
    var gpsAltitude: Double?
    var pressure: Double?
    var verticalSpeed: Double?
    var speed: Double?
    var ascent: Double = 0
    var descent: Double = 0
    var distance: Double = 0

    var altitudeUnit: AltitudeUnit = .metres
    var speedUnit: SpeedUnit = .kmh
    var pressureUnit: PressureUnit = .hPa
    var altitudeSource: AltitudeSource = .barometric
    var referencePressure: Double = Atmosphere.standardSeaLevelPressure
    var calibratedAt: Date?

    var tripActive = false
    var timestamp = Date()

    /// The altitude the trip totals were computed from.
    var altitude: Double? {
        altitudeSource == .barometric ? (barometricAltitude ?? gpsAltitude) : (gpsAltitude ?? barometricAltitude)
    }

    // MARK: App Group

    /// Shared with the widget extension. Must match both entitlements files.
    static let appGroup = "group.com.woodenshark.barometer"
    private static let key = "snapshot"

    static func load() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
