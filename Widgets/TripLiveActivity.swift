import ActivityKit
import SwiftUI
import WidgetKit

/// The trip on the lock screen and in the Dynamic Island.
///
/// Compact and minimal carry only the altitude — the one number a trip is
/// about. Expanded and the lock screen carry the same set as the dashboard,
/// so nothing said here can disagree with the app underneath.
struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripAttributes.self) { context in
            LockScreenView(snapshot: context.state.snapshot, startedAt: context.attributes.startedAt)
                .activityBackgroundTint(widgetTheme.background)
                .activitySystemActionForegroundColor(widgetTheme.primary)
        } dynamicIsland: { context in
            let snapshot = context.state.snapshot
            return DynamicIsland {
                // The island's corners curl in over the regions' edges, so
                // the text needs to stand clear of them.
                DynamicIslandExpandedRegion(.leading) {
                    Figure(caption: "Baro", value: snapshot.altitudeText(snapshot.barometricAltitude),
                           unit: snapshot.altitudeUnit.symbol, size: 26,
                           tint: snapshot.altitudeSource == .barometric ? widgetTheme.primary : widgetTheme.secondary)
                        .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Figure(caption: "GPS", value: snapshot.altitudeText(snapshot.gpsAltitude),
                           unit: snapshot.altitudeUnit.symbol, size: 26,
                           tint: snapshot.altitudeSource == .satellite ? widgetTheme.primary : widgetTheme.secondary)
                        .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StatsRow(snapshot: snapshot)
                        .padding(.top, 4)
                        .padding(.horizontal, 10)
                }
            } compactLeading: {
                ClimbGlyph(snapshot: snapshot)
            } compactTrailing: {
                AltitudeCompact(snapshot: snapshot)
            } minimal: {
                AltitudeCompact(snapshot: snapshot, minimal: true)
            }
            .keylineTint(widgetTheme.accent)
        }
    }
}

private struct AltitudeCompact: View {
    let snapshot: Snapshot
    var minimal = false

    var body: some View {
        if let text = snapshot.altitudeText(snapshot.altitude) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(text)
                    .font(widgetTheme.readout(minimal ? 13 : 15))
                    .foregroundStyle(widgetTheme.primary)
                    .contentTransition(.numericText())
                if !minimal {
                    Text(snapshot.altitudeUnit.symbol)
                        .font(widgetTheme.unit(9))
                        .foregroundStyle(widgetTheme.secondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Image(systemName: "mountain.2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(widgetTheme.tertiary)
        }
    }
}

private struct ClimbGlyph: View {
    let snapshot: Snapshot

    var body: some View {
        if let climb = snapshot.climb {
            Image(systemName: climb.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(climb.tint)
        } else {
            Image(systemName: "mountain.2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(widgetTheme.secondary)
        }
    }
}

private struct StatsRow: View {
    let snapshot: Snapshot

    var body: some View {
        HStack(spacing: 8) {
            if let climb = snapshot.climb {
                Figure(caption: "Climb", value: climb.text, size: 14, tint: climb.tint)
            }
            Figure(caption: "Ascent", value: snapshot.ascentText, size: 14)
            Figure(caption: "Descent", value: snapshot.descentText, size: 14)
            Figure(caption: "Speed", value: snapshot.speedText, unit: snapshot.speedUnit.symbol, size: 14)
        }
    }
}

private struct LockScreenView: View {
    let snapshot: Snapshot
    let startedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Figure(caption: "Baro", value: snapshot.altitudeText(snapshot.barometricAltitude),
                       unit: snapshot.altitudeUnit.symbol, size: 30,
                       tint: snapshot.altitudeSource == .barometric ? widgetTheme.primary : widgetTheme.secondary)
                Figure(caption: "GPS", value: snapshot.altitudeText(snapshot.gpsAltitude),
                       unit: snapshot.altitudeUnit.symbol, size: 30,
                       tint: snapshot.altitudeSource == .satellite ? widgetTheme.primary : widgetTheme.secondary)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Trip")
                        .font(widgetTheme.caption).tracking(1.1).textCase(.uppercase)
                        .foregroundStyle(widgetTheme.tertiary)
                    Text(startedAt, style: .timer)
                        .font(widgetTheme.detail)
                        .foregroundStyle(widgetTheme.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .frame(width: 64)
            }
            StatsRow(snapshot: snapshot)
        }
        .padding(14)
    }
}
