import SwiftUI

/// Setting the reference the barometric altimeter measures against.
///
/// Three ways in, ordered by how good the answer they give is: copy the GPS,
/// type the altitude you know you are at, or dial in a published QNH.
struct CalibrationView: View {
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
                Palette.background.ignoresSafeArea()

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
                        .foregroundStyle(Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
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
                .font(.readout(38))
                .foregroundStyle(Palette.primary)
                Text(settings.pressureUnit.symbol)
                    .font(.unit(15))
                    .foregroundStyle(Palette.secondary)
            }
            Text(calibrationAge)
                .font(.detail)
                .foregroundStyle(settings.calibrationIsStale ? Palette.accent : Palette.tertiary)
        }
    }

    private var calibrationAge: String {
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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    // Dimming a filled accent button turns it to mud and takes
                    // the label with it. Unavailable means outlined, not faded.
                    .background(
                        ready ? Palette.accent : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        if !ready {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Palette.hairline, lineWidth: 1)
                        }
                    }
                    .foregroundStyle(ready ? Color.black : Palette.tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!ready)
        }
    }

    private var gpsDetail: String {
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
                    .font(.readout(22))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .trailing) {
                        Text(settings.altitudeUnit.symbol)
                            .font(.unit(14))
                            .foregroundStyle(Palette.tertiary)
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
                    .font(.detail)
                    .foregroundStyle(Palette.descending)
            }

            HStack(spacing: 10) {
                TextField("1013.2", text: $pressureEntry)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .pressure)
                    .onChange(of: pressureEntry) { _, _ in rejectedPressure = false }
                    .font(.readout(22))
                    .foregroundStyle(Palette.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .trailing) {
                        Text(settings.pressureUnit.symbol)
                            .font(.unit(14))
                            .foregroundStyle(Palette.tertiary)
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
        .foregroundStyle(Palette.tertiary)
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
        let enabled: Bool

        var body: some View {
            Text("Set")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(enabled ? Palette.accent : Palette.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// A titled block. Not a boxed row — the sections are already separated by
    /// space, and a border around each would double the visual noise.
    private struct Card<Content: View>: View {
        let title: String
        let detail: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).captionStyle(Palette.secondary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.tertiary)
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
