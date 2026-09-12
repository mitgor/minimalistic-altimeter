import SwiftUI

/// A theme is what the four looks actually disagree on: colour, typeface,
/// how the trace is drawn and how the small cells are framed. Layout is not
/// in here on purpose — one screen, one arrangement, so the eye finds the
/// same number in the same place whichever skin is on.
struct Theme {
    enum TraceStyle { case line, dots, bars }
    enum CellStyle { case flat, tiles, boxed }

    let background: Color
    let surface: Color
    let hairline: Color

    let primary: Color
    let secondary: Color
    let tertiary: Color

    let accent: Color
    let ascending: Color
    let descending: Color

    let colorScheme: ColorScheme
    let fontDesign: Font.Design
    let weight: Font.Weight
    let traceStyle: TraceStyle
    let cellStyle: CellStyle
    let cornerRadius: CGFloat

    // MARK: Type scale

    /// The hero numerals. Always monospaced digits — proportional ones jitter
    /// sideways as they change, which reads as instability.
    func readout(_ size: CGFloat) -> Font {
        .system(size: size, weight: weight, design: fontDesign).monospacedDigit()
    }

    /// The unit that trails a hero numeral.
    func unit(_ size: CGFloat) -> Font {
        .system(size: size, weight: weight, design: fontDesign)
    }

    /// Small caps sitting above a readout.
    var caption: Font { .system(size: 11, weight: .semibold, design: fontDesign) }

    /// The supporting rows under and around the heroes.
    var detail: Font { .system(size: 13, weight: weight, design: fontDesign).monospacedDigit() }

    /// Buttons and other UI text that is not a reading.
    var control: Font { .system(size: 15, weight: .semibold, design: fontDesign) }

    /// Large rounded numerals set a touch tight read as one object; a
    /// monospaced face is already a grid and must be left alone.
    var readoutTracking: CGFloat { fontDesign == .monospaced ? 0 : -1.5 }
}

/// The user-facing choice, persisted by name.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case glass, phosphor, paper, lcd

    var id: String { rawValue }

    var name: String {
        switch self {
        case .glass: "Glass"
        case .phosphor: "Phosphor"
        case .paper: "Paper"
        case .lcd: "LCD"
        }
    }

    var theme: Theme {
        switch self {
        case .glass: .glass
        case .phosphor: .phosphor
        case .paper: .paper
        case .lcd: .lcd
        }
    }
}

extension Theme {
    /// Pure black rather than a dark grey: it costs nothing to draw on OLED,
    /// and it makes the readouts look like lit glass instead of ink on paper.
    /// One accent only, spent on whatever is live right now.
    static let glass = Theme(
        background: .black,
        surface: Color(white: 0.075),
        hairline: Color(white: 0.16),
        primary: .white,
        secondary: Color(white: 0.60),
        tertiary: Color(white: 0.36),
        accent: Color(red: 1.00, green: 0.62, blue: 0.16),
        ascending: Color(red: 0.36, green: 0.83, blue: 0.55),
        descending: Color(red: 0.98, green: 0.46, blue: 0.42),
        colorScheme: .dark,
        fontDesign: .rounded,
        weight: .medium,
        traceStyle: .line,
        cellStyle: .flat,
        cornerRadius: 12
    )

    /// A green terminal. Strictly one hue, so hierarchy is carried by
    /// brightness alone and the warning colour is simply the hottest green.
    static let phosphor: Theme = {
        let green = Color(red: 0.40, green: 0.95, blue: 0.45)
        return Theme(
            background: .black,
            surface: Color(red: 0.02, green: 0.07, blue: 0.03),
            hairline: green.opacity(0.22),
            primary: green,
            secondary: green.opacity(0.68),
            tertiary: green.opacity(0.42),
            accent: Color(red: 0.80, green: 1.00, blue: 0.80),
            ascending: green,
            descending: green,
            colorScheme: .dark,
            fontDesign: .monospaced,
            weight: .medium,
            traceStyle: .dots,
            cellStyle: .flat,
            cornerRadius: 4
        )
    }()

    /// Ink on paper. The accents are pulled darker than Glass's so they still
    /// pass contrast against white.
    static let paper = Theme(
        background: Color(white: 0.965),
        surface: .white,
        hairline: Color(white: 0.86),
        primary: Color(white: 0.09),
        secondary: Color(white: 0.42),
        tertiary: Color(white: 0.58),
        accent: Color(red: 0.86, green: 0.44, blue: 0.05),
        ascending: Color(red: 0.12, green: 0.60, blue: 0.35),
        descending: Color(red: 0.82, green: 0.27, blue: 0.24),
        colorScheme: .light,
        fontDesign: .rounded,
        weight: .medium,
        traceStyle: .line,
        cellStyle: .tiles,
        cornerRadius: 12
    )

    /// A segment LCD: one ink, a green-grey glass, square boxes. Greys are the
    /// ink at reduced opacity, which is what a real LCD's half-tone looks like.
    static let lcd: Theme = {
        let ink = Color(red: 0.09, green: 0.11, blue: 0.09)
        return Theme(
            background: Color(red: 0.77, green: 0.81, blue: 0.70),
            surface: Color(red: 0.72, green: 0.76, blue: 0.65),
            hairline: ink.opacity(0.55),
            primary: ink,
            secondary: ink.opacity(0.72),
            tertiary: ink.opacity(0.52),
            accent: ink,
            ascending: ink,
            descending: ink,
            colorScheme: .light,
            fontDesign: .monospaced,
            weight: .bold,
            traceStyle: .bars,
            cellStyle: .boxed,
            cornerRadius: 0
        )
    }()
}

// MARK: Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.glass
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Uppercase label styling — letterspaced, because small caps set tight are
/// hard to read at a glance.
private struct CaptionStyle: ViewModifier {
    @Environment(\.theme) private var theme
    let color: Color?

    func body(content: Content) -> some View {
        content
            .font(theme.caption)
            .tracking(1.3)
            .foregroundStyle(color ?? theme.tertiary)
            .textCase(.uppercase)
    }
}

extension View {
    func captionStyle(_ color: Color? = nil) -> some View {
        modifier(CaptionStyle(color: color))
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
