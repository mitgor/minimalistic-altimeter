import SwiftUI
import WidgetKit

/// The home-screen widget. WidgetKit cannot be live, so it shows the last
/// reading the app wrote and says how old it is — the age ticks on its own,
/// which is the one part of a widget that can be honest without a reload.
struct AltitudeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "altitude", provider: Provider()) { entry in
            AltitudeWidgetView(entry: entry)
                .containerBackground(widgetTheme.background, for: .widget)
        }
        .configurationDisplayName("Altitude")
        .description("The last altitude, pressure and trip totals.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: Snapshot(barometricAltitude: 1428, pressure: 863.2, ascent: 320, timestamp: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: Snapshot.load() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // One entry; the app asks for a reload whenever the figures move.
        completion(Timeline(entries: [Entry(date: .now, snapshot: Snapshot.load())], policy: .never))
    }
}

struct AltitudeWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                Figure(
                    caption: "Altitude \(snapshot.altitudeSource.label)",
                    value: snapshot.altitudeText(snapshot.altitude),
                    unit: snapshot.altitudeUnit.symbol,
                    size: family == .systemSmall ? 34 : 38
                )

                if family == .systemMedium {
                    HStack(spacing: 8) {
                        Figure(caption: "Pressure", value: snapshot.pressureText, unit: snapshot.pressureUnit.symbol, size: 16)
                        Figure(caption: "Ascent", value: snapshot.ascentText, size: 16)
                        Figure(caption: "Speed", value: snapshot.speedText, unit: snapshot.speedUnit.symbol, size: 16)
                    }
                } else {
                    Figure(caption: "Pressure", value: snapshot.pressureText, unit: snapshot.pressureUnit.symbol, size: 16)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if snapshot.tripActive {
                        Circle().fill(widgetTheme.ascending).frame(width: 5, height: 5)
                    }
                    Text("as of ")
                    + Text(snapshot.timestamp, style: .relative)
                    + Text(" ago")
                }
                .font(widgetTheme.caption)
                .foregroundStyle(widgetTheme.tertiary)
                .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mini Altimeter")
                    .font(widgetTheme.detail)
                    .foregroundStyle(widgetTheme.primary)
                Text("Open the app once to take a reading.")
                    .font(widgetTheme.caption)
                    .foregroundStyle(widgetTheme.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
