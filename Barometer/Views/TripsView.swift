import SwiftUI

/// Recorded trips, newest first. Tap one for its statistics.
struct TripsView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let store: TripStore
    let settings: Settings

    var body: some View {
        NavigationStack {
            Group {
                if store.trips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No trips yet")
                            .font(theme.detail)
                            .foregroundStyle(theme.secondary)
                        Text("Start a trip from the dashboard. It is recorded until you end it, and shows up here with its statistics.")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(24)
                } else {
                    List {
                        ForEach(store.trips) { trip in
                            NavigationLink(value: trip.id) {
                                TripRow(trip: trip, unit: settings.altitudeUnit)
                            }
                            .listRowBackground(theme.background)
                        }
                        .onDelete { offsets in
                            offsets.map { store.trips[$0] }.forEach(store.delete)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.background)
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { id in
                if let trip = store.trips.first(where: { $0.id == id }) {
                    TripDetailView(trip: trip, store: store, settings: settings)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(theme.accent)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.accent)
    }
}

private struct TripRow: View {
    @Environment(\.theme) private var theme
    let trip: Trip
    let unit: AltitudeUnit

    var body: some View {
        let s = TripSummary(trip)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.startedAt, format: .dateTime.day().month().hour().minute())
                    .font(theme.detail)
                    .foregroundStyle(theme.primary)
                Spacer()
                Text(trip.activity.name)
                    .font(theme.caption).tracking(1.1).textCase(.uppercase)
                    .foregroundStyle(theme.accent)
            }
            HStack(spacing: 14) {
                Text(Duration.seconds(s.duration), format: .time(pattern: .hourMinute))
                Text(Format.distance(s.distance, unit: unit))
                Text("↑ \(Format.distance(s.ascent, unit: unit))")
            }
            .font(theme.detail)
            .foregroundStyle(theme.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview {
    TripsView(store: .preview, settings: Settings(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
#endif
