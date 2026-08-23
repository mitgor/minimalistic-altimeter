import SwiftUI

/// The palette.
///
/// Pure black rather than a dark grey: it costs nothing to draw on OLED, and it
/// makes the readouts look like lit glass instead of ink on paper. One accent
/// only, spent on whatever is live right now.
enum Palette {
    static let background = Color.black
    static let surface = Color(white: 0.075)
    static let hairline = Color(white: 0.16)

    static let primary = Color.white
    static let secondary = Color(white: 0.60)
    static let tertiary = Color(white: 0.36)

    static let accent = Color(red: 1.00, green: 0.62, blue: 0.16)
    static let ascending = Color(red: 0.36, green: 0.83, blue: 0.55)
    static let descending = Color(red: 0.98, green: 0.46, blue: 0.42)
}

/// The type scale.
///
/// Every numeral is monospaced — without it the readouts jitter sideways as
/// digits change, which reads as instability in something meant to look precise.
/// Rounded faces keep the large sizes from feeling severe.
extension Font {
    /// The hero numerals.
    static func readout(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }

    /// The unit that trails a hero numeral.
    static func unit(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Small caps sitting above a readout.
    static let caption = Font.system(size: 11, weight: .semibold, design: .rounded)

    /// The supporting rows under and around the heroes.
    static let detail = Font.system(size: 13, weight: .medium, design: .rounded).monospacedDigit()
}

extension View {
    /// Uppercase label styling — letterspaced, because small caps set tight are
    /// hard to read at a glance.
    func captionStyle(_ color: Color = Palette.tertiary) -> some View {
        font(.caption)
            .tracking(1.3)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

enum Format {
    /// Formats a value with fixed decimals, so the readout never changes width.
    static func number(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Distance, switching to kilometres once metres stop being readable.
    static func distance(_ metres: Double, unit: AltitudeUnit) -> String {
        switch unit {
        case .metres:
            return metres < 1000 ? "\(number(metres)) m" : "\(number(metres / 1000, decimals: 2)) km"
        case .feet:
            let feet = unit.convert(metres)
            return feet < 5280 ? "\(number(feet)) ft" : "\(number(feet / 5280, decimals: 2)) mi"
        }
    }
}
