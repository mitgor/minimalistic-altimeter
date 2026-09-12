import ActivityKit
import Foundation
import WidgetKit

/// Pushes the instrument's readings to everything that is not the dashboard:
/// the Live Activity, the App Group the widgets read, and the watch.
///
/// A timer rather than observation, because every consumer here has a cost
/// per update — the island redraws, WidgetKit budgets reloads, the watch link
/// is a radio — and 2 Hz would burn all three for nothing anyone can see.
@MainActor
final class TripBroadcaster {
    private let instrument: Instrument
    private var timer: Timer?
    private var activity: Activity<TripAttributes>?
    private var lastWidgetReload: Snapshot?

    init(instrument: Instrument) {
        self.instrument = instrument
        PhoneLink.shared.activate()
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        publish()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func publish() {
        let snapshot = instrument.snapshot
        snapshot.save()
        PhoneLink.shared.send(snapshot)
        reloadWidgetsIfMoved(snapshot)
        syncActivity(snapshot)
    }

    /// WidgetKit rations reloads, so only ask when a figure on the widget
    /// would actually change: a few metres of altitude or a minute of age.
    private func reloadWidgetsIfMoved(_ snapshot: Snapshot) {
        if let last = lastWidgetReload,
           abs((snapshot.altitude ?? 0) - (last.altitude ?? 0)) < 3,
           snapshot.timestamp.timeIntervalSince(last.timestamp) < 60,
           snapshot.tripActive == last.tripActive {
            return
        }
        lastWidgetReload = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Live Activity

    private func syncActivity(_ snapshot: Snapshot) {
        let content = ActivityContent(state: TripAttributes.ContentState(snapshot: snapshot), staleDate: nil)

        if snapshot.tripActive {
            if let activity {
                Task { await activity.update(content) }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                activity = try? Activity.request(
                    attributes: TripAttributes(startedAt: instrument.tripStartedAt ?? Date()),
                    content: content
                )
            }
        } else {
            endActivities(with: content)
        }
    }

    /// Also sweeps up activities left behind by a previous launch — a crash
    /// mid-trip must not leave a lying island on the lock screen.
    private func endActivities(with content: ActivityContent<TripAttributes.ContentState>) {
        activity = nil
        for stale in Activity<TripAttributes>.activities {
            Task { await stale.end(content, dismissalPolicy: .immediate) }
        }
    }
}
