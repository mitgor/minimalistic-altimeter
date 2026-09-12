import Foundation
import Observation

/// Which sensor the headline altitude comes from.
enum AltitudeSource: String, CaseIterable, Identifiable, Sendable, Codable {
    case barometric, satellite

    var id: String { rawValue }
    var label: String { self == .barometric ? "BARO" : "GPS" }
    var name: String { self == .barometric ? "Barometric" : "Satellite" }

    var detail: String {
        switch self {
        case .barometric:
            "Pressure sensor. Very responsive and precise, but drifts as the weather changes — calibrate it when you can."
        case .satellite:
            "GNSS fix. Stable over hours, but noisy minute to minute and unavailable indoors."
        }
    }
}

/// User preferences, mirrored into `UserDefaults` on write.
///
/// Everything the app remembers lives here, and none of it leaves the device.
@MainActor
@Observable
final class Settings {

    var altitudeUnit: AltitudeUnit { didSet { store(altitudeUnit.rawValue, .altitudeUnit) } }
    var speedUnit: SpeedUnit { didSet { store(speedUnit.rawValue, .speedUnit) } }
    var pressureUnit: PressureUnit { didSet { store(pressureUnit.rawValue, .pressureUnit) } }
    var altitudeSource: AltitudeSource { didSet { store(altitudeSource.rawValue, .altitudeSource) } }

    /// Reference sea-level pressure — QNH — in hPa. Everything the barometric
    /// altimeter reports is measured against this one number.
    var referencePressure: Double { didSet { store(referencePressure, .referencePressure) } }

    /// When the reference was last set, so the UI can admit how stale it is.
    var calibratedAt: Date? { didSet { store(calibratedAt?.timeIntervalSince1970, .calibratedAt) } }

    var keepScreenAwake: Bool { didSet { store(keepScreenAwake, .keepScreenAwake) } }

    var theme: AppTheme { didSet { store(theme.rawValue, .theme) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // A metric default matches the sensor's own units and most of the world;
        // the US customary set is one tap away in Settings.
        altitudeUnit = defaults.string(forKey: Key.altitudeUnit.rawValue)
            .flatMap(AltitudeUnit.init) ?? .metres
        speedUnit = defaults.string(forKey: Key.speedUnit.rawValue)
            .flatMap(SpeedUnit.init) ?? .kmh
        pressureUnit = defaults.string(forKey: Key.pressureUnit.rawValue)
            .flatMap(PressureUnit.init) ?? .hPa
        altitudeSource = defaults.string(forKey: Key.altitudeSource.rawValue)
            .flatMap(AltitudeSource.init) ?? .barometric

        let stored = defaults.double(forKey: Key.referencePressure.rawValue)
        referencePressure = stored > 0 ? stored : Atmosphere.standardSeaLevelPressure

        let timestamp = defaults.object(forKey: Key.calibratedAt.rawValue) as? Double
        calibratedAt = timestamp.map(Date.init(timeIntervalSince1970:))

        keepScreenAwake = defaults.object(forKey: Key.keepScreenAwake.rawValue) as? Bool ?? true
        theme = defaults.string(forKey: Key.theme.rawValue).flatMap(AppTheme.init) ?? .glass
    }

    /// True once the reference is old enough that the weather has probably moved on.
    var calibrationIsStale: Bool {
        guard let calibratedAt else { return true }
        return Date().timeIntervalSince(calibratedAt) > 6 * 3600
    }

    func calibrate(referencePressure hPa: Double) {
        referencePressure = hPa
        calibratedAt = Date()
    }

    private enum Key: String {
        case altitudeUnit, speedUnit, pressureUnit, altitudeSource
        case referencePressure, calibratedAt, keepScreenAwake, theme
    }

    private func store(_ value: Any?, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
