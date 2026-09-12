import SwiftUI

@main
struct MiniAltimeterWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchDashboardView(model: model)
                .onAppear { model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.start() } else { model.stop() }
                }
        }
    }
}
