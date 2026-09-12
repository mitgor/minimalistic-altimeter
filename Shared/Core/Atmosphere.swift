import Foundation

/// International Standard Atmosphere conversions.
///
/// Everything here is pure maths on a pressure reading, which is what lets the
/// altimeter work with no network and no GPS fix: the barometer alone is enough
/// once we know which pressure to call "sea level".
///
/// This is the single-layer troposphere approximation, so it tracks the full ISA
/// table to within 0.15 m below 3000 m, ~4 m at 5000 m, and ~10 m at 8000 m.
/// Calibration round-trips exactly at any altitude, which matters more: an
/// uncalibrated reference costs about 8 m for every hectopascal it is stale by,
/// dwarfing the model error anywhere people actually walk.
enum Atmosphere {

    /// ISA sea-level pressure, in hectopascals.
    static let standardSeaLevelPressure = 1013.25

    /// `T0 / L` — the ISA scale height, in metres.
    private static let scaleHeight = 44_330.77

    /// `R·L / (g·M)` — the troposphere exponent.
    private static let exponent = 0.190_263_2

    /// Altitude implied by a station pressure, given the sea-level pressure in force.
    ///
    /// - Parameters:
    ///   - pressure: Station (raw sensor) pressure in hPa.
    ///   - seaLevelPressure: Reference sea-level pressure — QNH — in hPa.
    /// - Returns: Metres above mean sea level.
    static func altitude(pressure: Double, seaLevelPressure: Double) -> Double {
        guard pressure > 0, seaLevelPressure > 0 else { return 0 }
        return scaleHeight * (1 - pow(pressure / seaLevelPressure, exponent))
    }

    /// The sea-level pressure that a station reading at a known altitude implies.
    ///
    /// This is the inverse of `altitude(pressure:seaLevelPressure:)` and is how
    /// calibration works: tell us where you are, we solve for the QNH.
    static func seaLevelPressure(stationPressure: Double, altitude: Double) -> Double {
        guard stationPressure > 0, altitude < scaleHeight else { return standardSeaLevelPressure }
        return stationPressure / pow(1 - altitude / scaleHeight, 1 / exponent)
    }
}
