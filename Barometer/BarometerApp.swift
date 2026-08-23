import SwiftUI

@main
struct BarometerApp: App {
    @State private var instrument = Instrument()

    var body: some Scene {
        WindowGroup {
            DashboardView(instrument: instrument)
        }
    }
}
