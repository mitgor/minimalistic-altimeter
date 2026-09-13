import SwiftUI

/// The whole app, on one screen.
///
/// Two heroes — altitude, then speed — with everything else demoted to a single
/// strip at the bottom or moved into a sheet. The research on instrument UIs is
/// unanimous that a second competing focal point is what kills glanceability, so
/// there are exactly two, separated by a rule and a lot of empty space.
struct DashboardView: View {
    @Environment(\.theme) private var theme
    let instrument: Instrument

    @State private var showingCalibration = false
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private var settings: Settings { instrument.settings }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                statusRail
                    .padding(.bottom, 28)

                altitudeBlock
                    .padding(.bottom, 20)

                // The trace is the altitude block's own history, so it stays
                // tied to it. All the slack goes below, not between them.
                trace
                    .frame(height: 64)

                Spacer(minLength: 24)

                Divider1px()
                    .padding(.vertical, 22)

                speedBlock

                Spacer(minLength: 20)

                bottomStrip
            }
            .padding(.horizontal, 26)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(instrument: instrument)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(instrument: instrument)
        }
        .onAppear {
            instrument.start()
            UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
        }
        .onChange(of: scenePhase) { _, phase in
            // The sensors are the battery cost, so they stop the moment the app
            // is not on screen — unless a trip has asked them to stay.
            if phase == .active {
                instrument.start()
                UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
                if !instrument.tripActive { instrument.stop() }
            }
        }
    }

    // MARK: Rail

    private var statusRail: some View {
        HStack(spacing: 10) {
            Button {
                toggleTrip()
            } label: {
                SourcePill(label: instrument.tripActive ? "End trip" : "Start trip", isLive: instrument.tripActive)
            }
            .buttonStyle(.plain)
            .accessibilityHint(instrument.tripActive
                ? "Stops background tracking and the Live Activity"
                : "Keeps tracking when the app is closed and shows altitude in the Dynamic Island")

            // Only speaks up when something is wrong. With both altitudes on
            // screen there is no source to announce here any more.
            if needsCalibration {
                Button {
                    showingCalibration = true
                } label: {
                    SourcePill(
                        label: settings.calibratedAt == nil ? "Uncalibrated" : "Reference stale",
                        isLive: false,
                        isWarning: true
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            FixBars(quality: instrument.sensors.fixQuality)

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(height: 32)
    }

    private var needsCalibration: Bool {
        instrument.effectiveSource == .barometric && settings.calibrationIsStale
    }

    // MARK: Altitude

    private var altitudeBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Altitude").captionStyle(theme.secondary)

            // Side by side rather than one hero with a source switch: the two
            // sensors fail in different ways — the barometer drifts with the
            // weather, the fix wanders indoors — and seeing them together is
            // what tells you whether to believe either.
            HStack(alignment: .top, spacing: 14) {
                altitudeColumn(.barometric)
                altitudeColumn(.satellite)
            }

            HStack(spacing: 14) {
                if instrument.verticalSpeed != nil {
                    verticalSpeedBadge
                }
                trustFigure

                Spacer()

                Button {
                    showingCalibration = true
                } label: {
                    Text("Calibrate")
                        .font(theme.detail)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func altitudeColumn(_ source: AltitudeSource) -> some View {
        let isPrimary = settings.altitudeSource == source
        let metres = source == .barometric
            ? instrument.barometricAltitude
            : instrument.sensors.gpsAltitude

        return Readout(
            caption: LocalizedStringKey(source.label),
            value: metres.map { Format.number(settings.altitudeUnit.convert($0)) },
            unit: settings.altitudeUnit.symbol,
            placeholder: placeholder(for: source),
            size: 52,
            tint: isPrimary ? theme.primary : theme.secondary,
            captionTint: isPrimary ? theme.accent : theme.tertiary,
            marked: isPrimary
        )
        .contentShape(.rect)
        .onTapGesture { select(source) }
        .accessibilityHint(isPrimary ? "Drives the trace and trip totals" : "Tap to make primary")
    }

    private func placeholder(for source: AltitudeSource) -> LocalizedStringKey {
        switch source {
        case .barometric:
            return instrument.sensors.barometerAvailable ? "Waiting" : "No sensor"
        case .satellite:
            if instrument.sensors.locationDenied { return "Location off" }
            // A fix that carries no vertical accuracy is common indoors and in
            // the Simulator. Saying "no fix" there would be wrong — position is
            // fine, it is the altitude that is missing.
            return instrument.sensors.fixQuality == 0 ? "No fix" : "No altitude"
        }
    }

    /// The gap between the sources when both are reading, and the primary's own
    /// error bar when only one is.
    @ViewBuilder
    private var trustFigure: some View {
        let unit = settings.altitudeUnit

        if let divergence = instrument.divergence {
            Text("\u{0394} \(Format.number(abs(unit.convert(divergence)))) \(unit.symbol)")
                .font(theme.detail)
                .foregroundStyle(abs(divergence) > 30 ? theme.accent : theme.tertiary)
                .accessibilityLabel("Difference between sources")
        } else if let accuracy = instrument.altitudeAccuracy {
            Text("\u{00B1} \(Format.number(unit.convert(accuracy))) \(unit.symbol)")
                .font(theme.detail)
                .foregroundStyle(theme.tertiary)
        }
    }

    private var verticalSpeedBadge: some View {
        let rate = instrument.verticalSpeed ?? 0

        // Anything under 10 cm/s is the sensor breathing, not you climbing.
        let isMoving = abs(rate) > 0.1
        let tint = !isMoving ? theme.tertiary : (rate > 0 ? theme.ascending : theme.descending)

        return HStack(spacing: 4) {
            Image(systemName: !isMoving ? "equal" : (rate > 0 ? "arrow.up" : "arrow.down"))
                .font(.system(size: 10, weight: .bold))
            Text("\(Format.number(abs(settings.altitudeUnit.convert(rate)), decimals: 1)) \(settings.altitudeUnit.symbol)/s")
                .font(theme.detail)
        }
        .foregroundStyle(tint)
        .contentTransition(.numericText())
        .animation(.easeOut(duration: 0.3), value: isMoving)
        .accessibilityLabel("Vertical speed")
    }

    private var trace: some View {
        AltitudeTrace(
            samples: instrument.track.samples,
            range: instrument.track.range,
            tint: needsCalibration ? theme.accent : theme.secondary
        )
    }

    // MARK: Speed

    private var speedBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Readout(
                caption: "Speed",
                value: instrument.hasSpeedFix
                    ? Format.number(settings.speedUnit.convert(instrument.speed))
                    : nil,
                unit: settings.speedUnit.symbol,
                placeholder: instrument.sensors.locationDenied
                    ? "Location off"
                    : "Waiting for a fix",
                size: 82
            )

            if instrument.sensors.locationDenied {
                // Without location the speed readout can never fill in, so say
                // why rather than leaving a dash there forever.
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Location off — enable in Settings")
                            .font(theme.detail)
                    }
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 18) {
                    // Withheld until the first fix — zeros before then would
                    // claim you had stood still, not that nothing is known yet.
                    if instrument.hasSpeedFix || instrument.topSpeed > 0 {
                        Text("MAX \(Format.number(settings.speedUnit.convert(instrument.topSpeed)))")
                    }
                    if let average = instrument.averageSpeed {
                        Text("AVG \(Format.number(settings.speedUnit.convert(average)))")
                    }

                    if let heading = instrument.heading {
                        Text(heading)
                            .foregroundStyle(theme.secondary)
                    }

                    Spacer()
                }
                .font(theme.detail)
                .foregroundStyle(theme.tertiary)
                .contentTransition(.numericText())
            }
        }
    }

    // MARK: Bottom strip

    private var bottomStrip: some View {
        VStack(spacing: 16) {
            if theme.cellStyle == .flat {
                Divider1px()
            }

            HStack(spacing: theme.cellStyle == .flat ? 0 : 6) {
                StatCell(
                    label: "Pressure",
                    value: pressureText
                )
                StatCell(
                    label: "Ascent",
                    value: Format.distance(instrument.track.ascent, unit: settings.altitudeUnit)
                )
                StatCell(
                    label: "Descent",
                    value: Format.distance(instrument.track.descent, unit: settings.altitudeUnit)
                )
                StatCell(
                    label: "Distance",
                    value: Format.distance(instrument.distance, unit: settings.altitudeUnit)
                )
            }
        }
    }

    private var pressureText: String {
        guard let pressure = instrument.sensors.stationPressure else { return "––" }
        let unit = settings.pressureUnit
        return "\(Format.number(unit.convert(pressure), decimals: unit.fractionDigits)) \(unit.symbol)"
    }

    // MARK: Actions

    private func toggleTrip() {
        if instrument.tripActive {
            instrument.endTrip()
        } else {
            instrument.startTrip()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Picks which source the trace, climb rate and ascent totals derive from.
    private func select(_ source: AltitudeSource) {
        guard source != settings.altitudeSource else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            settings.altitudeSource = source
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

#if DEBUG
#Preview("Dashboard") {
    DashboardView(instrument: .preview())
}

#Preview("Uncalibrated, no fix") {
    DashboardView(
        instrument: .preview(
            sensors: .preview(gpsAltitude: nil, speed: nil, course: nil),
            calibrated: false
        )
    )
}

#Preview("No barometer") {
    DashboardView(instrument: .preview(sensors: .preview(pressure: nil)))
}
#endif
