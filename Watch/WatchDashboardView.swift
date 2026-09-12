import SwiftUI

/// One column, the phone's order, cut to what a wrist can carry: the primary
/// altitude large, the other source small beside it, then the trip figures.
struct WatchDashboardView: View {
    let model: WatchModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            if let snapshot = model.snapshot {
                readings(snapshot)
            } else {
                waiting
            }
        }
        .background(theme.background)
    }

    private func readings(_ snapshot: Snapshot) -> some View {
        let primary = snapshot.altitudeSource
        let secondary: AltitudeSource = primary == .barometric ? .satellite : .barometric
        let unit = snapshot.altitudeUnit

        return VStack(alignment: .leading, spacing: 10) {
            Readout(
                caption: primary.label,
                value: snapshot.altitudeText(altitude(snapshot, primary)),
                unit: unit.symbol,
                placeholder: "No reading",
                size: 40,
                captionTint: theme.accent,
                marked: true
            )

            HStack(spacing: 6) {
                Text(secondary.label).captionStyle()
                Text(snapshot.altitudeText(altitude(snapshot, secondary)).map { "\($0) \(unit.symbol)" } ?? "No reading")
                    .font(theme.detail)
                    .foregroundStyle(theme.secondary)
                Spacer()
                if let climb = snapshot.climb {
                    Image(systemName: climb.symbol).font(.system(size: 9, weight: .bold))
                    Text(climb.text).font(theme.detail)
                }
            }
            .foregroundStyle(theme.tertiary)

            Divider1px()

            HStack(spacing: 0) {
                StatCell(label: "Ascent", value: snapshot.ascentText)
                StatCell(label: "Descent", value: snapshot.descentText)
            }
            HStack(spacing: 0) {
                StatCell(label: "Speed", value: snapshot.speedText.map { "\($0) \(snapshot.speedUnit.symbol)" } ?? "No fix")
                StatCell(label: "Distance", value: snapshot.distanceText)
            }

            footer(snapshot)
        }
        .padding(.horizontal, 4)
    }

    private func altitude(_ snapshot: Snapshot, _ source: AltitudeSource) -> Double? {
        source == .barometric ? snapshot.barometricAltitude : snapshot.gpsAltitude
    }

    /// Where the numbers came from. Never silent about a mirrored reading.
    private func footer(_ snapshot: Snapshot) -> some View {
        HStack(spacing: 4) {
            if snapshot.tripActive {
                Circle().fill(theme.ascending).frame(width: 5, height: 5)
            }
            switch model.source {
            case .wrist:
                Text("On wrist")
            case .phone:
                Text("From iPhone, ") + Text(snapshot.timestamp, style: .relative) + Text(" ago")
            }
        }
        .font(theme.caption)
        .foregroundStyle(theme.tertiary)
        .padding(.top, 4)
    }

    private var waiting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.source == .wrist ? "Waiting for sensors" : "Waiting for iPhone")
                .font(theme.detail)
                .foregroundStyle(theme.secondary)
            if model.source == .phone {
                Text("This watch has no barometer. Open Mini Altimeter on the phone and the readings appear here.")
                    .font(theme.caption)
                    .foregroundStyle(theme.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
