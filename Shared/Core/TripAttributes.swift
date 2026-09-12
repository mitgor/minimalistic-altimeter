#if canImport(ActivityKit)
import ActivityKit
import Foundation

/// The Live Activity behind the Dynamic Island and lock-screen readout.
///
/// Its whole dynamic state is a `Snapshot`, so the island can never show a
/// number the dashboard would not.
struct TripAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var snapshot: Snapshot
    }

    var startedAt: Date
}
#endif
