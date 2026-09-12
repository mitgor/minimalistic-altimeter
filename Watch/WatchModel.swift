import CoreMotion
import Foundation
import Observation
import WatchConnectivity

/// Picks, once, where the watch's numbers come from.
///
/// A watch with a barometer is a complete altimeter and runs the shared
/// `Instrument` on its own sensors, borrowing only the phone's reference
/// pressure and units. One without mirrors the phone's latest snapshot and
/// says so, because a reading from another device is a different claim.
@MainActor
@Observable
final class WatchModel {
    enum Source { case wrist, phone }

    let source: Source
    let instrument: Instrument?

    /// The phone's last snapshot, in either mode — the mirror's whole feed,
    /// and the standalone's source of calibration.
    private(set) var mirrored: Snapshot?

    @ObservationIgnored private var link: WatchLink?

    init() {
        if CMAltimeter.isRelativeAltitudeAvailable() {
            source = .wrist
            instrument = Instrument()
        } else {
            source = .phone
            instrument = nil
        }
        let link = WatchLink { [weak self] snapshot in
            Task { @MainActor in self?.receive(snapshot) }
        }
        self.link = link
        link.activate()
    }

    var snapshot: Snapshot? {
        instrument?.snapshot ?? mirrored
    }

    func start() { instrument?.start() }
    func stop() { instrument?.stop() }

    private func receive(_ snapshot: Snapshot) {
        mirrored = snapshot
        guard let instrument else { return }
        // The phone is where calibration happens, so its reference wins
        // whenever it is newer than what the wrist already has.
        let settings = instrument.settings
        settings.altitudeUnit = snapshot.altitudeUnit
        settings.speedUnit = snapshot.speedUnit
        settings.pressureUnit = snapshot.pressureUnit
        settings.altitudeSource = snapshot.altitudeSource
        if let stamp = snapshot.calibratedAt, stamp > (settings.calibratedAt ?? .distantPast) {
            settings.referencePressure = snapshot.referencePressure
            settings.calibratedAt = stamp
        }
    }
}

/// The wrist end of the link. Receives application context only.
final class WatchLink: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let onSnapshot: @Sendable (Snapshot) -> Void

    init(onSnapshot: @escaping @Sendable (Snapshot) -> Void) {
        self.onSnapshot = onSnapshot
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Context delivered while the app was not running is waiting here.
        deliver(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        deliver(context)
    }

    private func deliver(_ context: [String: Any]) {
        guard let data = context["snapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        onSnapshot(snapshot)
    }
}
