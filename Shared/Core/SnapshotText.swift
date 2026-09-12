import SwiftUI

/// Display strings for a snapshot, so the widgets and the watch format a
/// figure exactly the way the dashboard does.
extension Snapshot {
    func altitudeText(_ metres: Double?) -> String? {
        metres.map { Format.number(altitudeUnit.convert($0)) }
    }

    var speedText: String? {
        speed.map { Format.number(speedUnit.convert($0)) }
    }

    var pressureText: String? {
        pressure.map { Format.number(pressureUnit.convert($0), decimals: pressureUnit.fractionDigits) }
    }

    var ascentText: String { Format.distance(ascent, unit: altitudeUnit) }
    var descentText: String { Format.distance(descent, unit: altitudeUnit) }
    var distanceText: String { Format.distance(distance, unit: altitudeUnit) }

    /// Climb rate as a glyph and figure, or nothing when it is not known.
    var climb: (symbol: String, text: String, tint: Color)? {
        guard let verticalSpeed else { return nil }
        let moving = abs(verticalSpeed) > 0.1
        let symbol = !moving ? "equal" : (verticalSpeed > 0 ? "arrow.up" : "arrow.down")
        let tint = !moving ? Theme.glass.tertiary : (verticalSpeed > 0 ? Theme.glass.ascending : Theme.glass.descending)
        return (symbol, "\(Format.number(abs(altitudeUnit.convert(verticalSpeed)), decimals: 1)) \(altitudeUnit.symbol)/s", tint)
    }
}
