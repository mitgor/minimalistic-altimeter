import Foundation

enum AltitudeUnit: String, CaseIterable, Identifiable, Sendable {
    case metres, feet

    var id: String { rawValue }
    var symbol: String { self == .metres ? "m" : "ft" }
    var name: String { self == .metres ? "Metres" : "Feet" }

    /// Converts metres — the unit everything is stored in — for display.
    func convert(_ metres: Double) -> Double {
        self == .metres ? metres : metres * 3.280_839_895
    }

    /// Converts a displayed value back into metres.
    func toMetres(_ value: Double) -> Double {
        self == .metres ? value : value / 3.280_839_895
    }
}

enum SpeedUnit: String, CaseIterable, Identifiable, Sendable {
    case kmh, mph, knots, ms

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kmh: "km/h"
        case .mph: "mph"
        case .knots: "kn"
        case .ms: "m/s"
        }
    }

    var name: String {
        switch self {
        case .kmh: "Kilometres per hour"
        case .mph: "Miles per hour"
        case .knots: "Knots"
        case .ms: "Metres per second"
        }
    }

    /// Converts metres per second for display.
    func convert(_ metresPerSecond: Double) -> Double {
        switch self {
        case .kmh: metresPerSecond * 3.6
        case .mph: metresPerSecond * 2.236_936_292
        case .knots: metresPerSecond * 1.943_844_492
        case .ms: metresPerSecond
        }
    }
}

enum PressureUnit: String, CaseIterable, Identifiable, Sendable {
    case hPa, inHg, mmHg

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .hPa: "hPa"
        case .inHg: "inHg"
        case .mmHg: "mmHg"
        }
    }

    var name: String {
        switch self {
        case .hPa: "Hectopascals"
        case .inHg: "Inches of mercury"
        case .mmHg: "Millimetres of mercury"
        }
    }

    /// Digits worth showing — inHg needs more than hPa to resolve the same step.
    var fractionDigits: Int { self == .inHg ? 2 : 1 }

    /// Converts hectopascals — the storage unit — for display.
    func convert(_ hPa: Double) -> Double {
        switch self {
        case .hPa: hPa
        case .inHg: hPa * 0.029_529_98
        case .mmHg: hPa * 0.750_061_7
        }
    }

    func toHectopascals(_ value: Double) -> Double {
        switch self {
        case .hPa: value
        case .inHg: value / 0.029_529_98
        case .mmHg: value / 0.750_061_7
        }
    }
}
