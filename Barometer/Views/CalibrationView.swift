import SwiftUI

/// Setting the reference the barometric altimeter measures against.
///
/// Three ways in, ordered by how good the answer they give is: copy the GPS,
/// type the altitude you know you are at, or dial in a published QNH.
struct CalibrationView: View {
    @Environment(\.theme) private var theme
    let instrument: Instrument
    @Environment(\.dismiss) private var dismiss

    @State private var altitudeEntry = ""
    @State private var rejectedPressure = false
    @State private var pressureEntry = ""
    @FocusState private var focus: Field?

    private enum Field { case altitude, pressure }

    private var settings: Settings { instrument.settings }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        current
                        gpsOption
                        altitudeOption
                        pressureOption
                        footnote
                    }
                    .padding(24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Calibrate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .presentationDetents([.large])
        .onAppear {
            pressureEntry = Format.number(
                settings.pressureUnit.convert(settings.referencePressure),
                decimals: settings.pressureUnit.fractionDigits
            )
        }
    }

    // MARK: Sections

    private var current: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reference").captionStyle()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.number(
                    settings.pressureUnit.convert(settings.referencePressure),
                    decimals: settings.pressureUnit.fractionDigits
                ))
                .font(theme.readout(38))
                .foregroundStyle(theme.primary)
                Text(settings.pressureUnit.symbol)
                    .font(theme.unit(15))
                    .foregroundStyle(theme.secondary)
            }
            Text(calibrationAge)
                .font(theme.detail)
                .foregroundStyle(settings.calibrationIsStale ? theme.accent : theme.tertiary)
        }
    }

    private var calibrationAge: LocalizedStringKey {
        guard let calibratedAt = settings.calibratedAt else {
            return "Never calibrated — showing standard-atmosphere altitude"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Set \(formatter.localizedString(for: calibratedAt, relativeTo: Date()))"
    }

    private var gpsOption: some View {
        let ready = instrument.sensors.gpsAltitude != nil

        return Card(title: "Match GPS", detail: gpsDetail) {
            Button {
                if instrument.calibrateFromGPS() { finish() }
            } label: {
                Label("Use satellite altitude", systemImage: "location.fill")
                    .font(theme.control)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    // Dimming a filled accent button turns it to mud and takes
                    // the label with it. Unavailable means outlined, not faded.
                    .background(
                        ready ? theme.accent : theme.surface,
                        in: RoundedRectangle(cornerRadius: theme.cornerRadius)
                    )
                    .overlay {
                        if !ready {
                            RoundedRectangle(cornerRadius: theme.cornerRadius)
                                .stroke(theme.hairline, lineWidth: 1)
                        }
                    }
                    .foregroundStyle(ready ? theme.background : theme.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!ready)
        }
    }

    private var gpsDetail: LocalizedStringKey {
        guard let gpsAltitude = instrument.sensors.gpsAltitude else {
            return "Waiting for a fix. This needs a clear view of the sky."
        }
        return "The fix currently reads \(Format.number(settings.altitudeUnit.convert(gpsAltitude))) \(settings.altitudeUnit.symbol)."
    }

    private var altitudeOption: some View {
        Card(title: "Known altitude", detail: "A trailhead sign, a summit marker, a chart — anything you trust.") {
            HStack(spacing: 10) {
                TextField("0", text: $altitudeEntry)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focus, equals: .altitude)
                    .font(theme.readout(22))
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                    .overlay(alignment: .trailing) {
                        Text(settings.altitudeUnit.symbol)
                            .font(theme.unit(14))
                            .foregroundStyle(theme.tertiary)
                            .padding(.trailing, 14)
                    }

                Button {
                    guard let value = Double(altitudeEntry.replacingOccurrences(of: ",", with: ".")) else { return }
                    if instrument.calibrate(toAltitude: settings.altitudeUnit.toMetres(value)) { finish() }
                } label: {
                    SetLabel(enabled: !altitudeEntry.isEmpty)
                }
                .buttonStyle(.plain)
                .disabled(altitudeEntry.isEmpty)
            }
        }
    }

    private var pressureOption: some View {
        Card(title: "Sea-level pressure", detail: "The QNH from an airfield or weather report near you.") {
            if rejectedPressure {
                Text("Sea-level pressure sits between 800 and 1100 hPa.")
                    .font(theme.detail)
                    .foregroundStyle(theme.descending)
            }

            HStack(spacing: 10) {
                TextField("1013.2", text: $pressureEntry)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .pressure)
                    .onChange(of: pressureEntry) { _, _ in rejectedPressure = false }
                    .font(theme.readout(22))
                    .foregroundStyle(theme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                    .overlay(alignment: .trailing) {
                        Text(settings.pressureUnit.symbol)
                            .font(theme.unit(14))
                            .foregroundStyle(theme.tertiary)
                            .padding(.trailing, 14)
                    }

                Button {
                    guard let value = Double(pressureEntry.replacingOccurrences(of: ",", with: ".")) else { return }
                    let hPa = settings.pressureUnit.toHectopascals(value)
                    guard (800...1100).contains(hPa) else {
                        rejectedPressure = true
                        return
                    }
                    settings.calibrate(referencePressure: hPa)
                    finish()
                } label: {
                    SetLabel(enabled: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footnote: some View {
        Text("""
        The pressure sensor measures altitude changes to within a metre or so, \
        but it cannot know how far it is to sea level on its own — weather moves \
        the whole column up and down. Calibration pins it. Expect to redo it \
        every few hours, or whenever the weather turns.
        """)
        .font(.system(size: 13))
        .foregroundStyle(theme.tertiary)
        .lineSpacing(3)
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        focus = nil
        dismiss()
    }

    /// The pill on a Set button. Built as the button's label so the padded
    /// rectangle is the hit region, not just the glyphs inside it.
    private struct SetLabel: View {
        @Environment(\.theme) private var theme
        let enabled: Bool

        var body: some View {
            Text("Set")
                .font(theme.control)
                .foregroundStyle(enabled ? theme.accent : theme.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
        }
    }

    /// A titled block. Not a boxed row — the sections are already separated by
    /// space, and a border around each would double the visual noise.
    private struct Card<Content: View>: View {
        @Environment(\.theme) private var theme
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).captionStyle(theme.secondary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.tertiary)
                    .lineSpacing(2)
                content
                    .padding(.top, 2)
            }
        }
    }
}

#if DEBUG
#Preview {
    CalibrationView(instrument: .preview(calibrated: false))
}
#endif
