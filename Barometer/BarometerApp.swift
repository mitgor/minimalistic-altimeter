import SwiftUI

@main
struct BarometerApp: App {
    @State private var instrument = Instrument()
    @State private var trips = TripStore()
    @State private var broadcaster: TripBroadcaster?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView(instrument: instrument, trips: trips)
                .environment(\.theme, instrument.settings.theme.theme)
                .onAppear {
                    if broadcaster == nil { broadcaster = TripBroadcaster(instrument: instrument) }
                    broadcaster?.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Off screen, the only reason to keep publishing is a trip
                    // keeping the process alive for the island.
                    if phase == .active || instrument.tripActive {
                        broadcaster?.start()
                    } else {
                        broadcaster?.publish()
                        broadcaster?.stop()
                    }
                }
        }
    }
}
