import SwiftUI

/// The widget-sized readouts. They share the app's palette and type but not
/// its components, which are sized for a screen you hold, not one you glance
/// at from across the lock screen.
///
/// Drawn in Glass only: the extension cannot see the app's theme without
/// another shared setting, and the island is dark by design anyway.
let widgetTheme = Theme.glass

struct Figure: View {
    let caption: LocalizedStringKey
    let value: String?
    var unit = ""
    var size: CGFloat = 28
    var tint: Color = widgetTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(caption)
                .font(widgetTheme.caption)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(widgetTheme.tertiary)
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(widgetTheme.readout(size))
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(widgetTheme.unit(size * 0.4))
                        .foregroundStyle(widgetTheme.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            } else {
                // The same rule as the dashboard: a word, never a dash or a zero.
                Text("No reading")
                    .font(widgetTheme.unit(size * 0.45))
                    .foregroundStyle(widgetTheme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

