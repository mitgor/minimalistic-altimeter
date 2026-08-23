import SwiftUI

struct SettingsView: View {
    let instrument: Instrument
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingReset = false

    var body: some View {
        // Bound locally so the pickers write straight through to the stored
        // preferences rather than round-tripping via `Instrument`.
        @Bindable var settings = instrument.settings

        return NavigationStack {
            Form {
                Section("Units") {
                    Picker("Altitude", selection: $settings.altitudeUnit) {
                        ForEach(AltitudeUnit.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Speed", selection: $settings.speedUnit) {
                        ForEach(SpeedUnit.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Pressure", selection: $settings.pressureUnit) {
                        ForEach(PressureUnit.allCases) { Text($0.name).tag($0) }
                    }
                }

                Section {
                    Picker("Primary", selection: $settings.altitudeSource) {
                        ForEach(AltitudeSource.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text(settings.altitudeSource.detail)
                        .font(.system(size: 13))
                        // Tertiary is calibrated against pure black; on the
                        // Form's raised rows it drops below readable.
                        .foregroundStyle(Palette.secondary)
                } header: {
                    Text("Primary source")
                } footer: {
                    if instrument.sensors.barometerAvailable {
                        Text("Both altitudes are always shown. The primary is the one the trace, climb rate, and ascent totals are computed from.")
                    } else {
                        Text("This device has no pressure sensor, so only the satellite altitude will read.")
                    }
                }

                Section("Display") {
                    Toggle("Keep screen awake", isOn: $settings.keepScreenAwake)
                        .onChange(of: settings.keepScreenAwake) { _, awake in
                            UIApplication.shared.isIdleTimerDisabled = awake
                        }
                }

                Section {
                    Button("Reset trip", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Clears the trace, ascent and descent totals, distance, and max speed.")
                }

                Section {
                    LabeledContent("Barometer", value: instrument.sensors.barometerAvailable ? "Available" : "Not available")
                    LabeledContent("Location", value: authorizationText)
                } header: {
                    Text("Sensors")
                } footer: {
                    Text("Both sensors are on-device. This app makes no network requests and works fully offline.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
            }
            .confirmationDialog("Reset trip?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    instrument.resetTrip()
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Palette.accent)
    }

    private var authorizationText: String {
        switch instrument.sensors.authorization {
        case .authorizedAlways, .authorizedWhenInUse: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        default: "Not requested"
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(instrument: .preview())
}
#endif
