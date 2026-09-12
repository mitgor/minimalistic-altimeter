import CoreLocation
import CoreMotion
import Foundation
import Observation

/// Owns the two hardware sources and publishes what they report.
///
/// Both are entirely on-device: `CMAltimeter` reads the pressure transducer and
/// `CLLocationManager` reads GNSS. Neither needs a network, so the whole app
/// keeps working in a valley with no signal — which is exactly where it matters.
@MainActor
@Observable
final class SensorEngine {

    // MARK: Barometer

    /// Station pressure in hPa — the raw reading at wherever the phone is.
    private(set) var stationPressure: Double?
    private(set) var barometerAvailable = CMAltimeter.isRelativeAltitudeAvailable()

    // MARK: GNSS

    /// Metres above mean sea level, as the location fix reports it.
    private(set) var gpsAltitude: Double?
    /// Metres per second over the ground. `nil` whenever the fix can't measure it.
    private(set) var groundSpeed: Double?
    /// Degrees from true north, or `nil` when stationary.
    private(set) var course: Double?
    private(set) var horizontalAccuracy: Double?
    private(set) var verticalAccuracy: Double?
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var lastFix: Date?

    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
    /// Held strongly here because `CLLocationManager.delegate` is weak.
    @ObservationIgnored private var locationProxy: LocationProxy?
    private var running = false

    init() {
        let proxy = LocationProxy(engine: self)
        locationProxy = proxy
        locationManager.delegate = proxy
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .fitness
        locationManager.distanceFilter = kCLDistanceFilterNone
        authorization = locationManager.authorizationStatus
    }

    // MARK: Lifecycle

    func start() {
        guard !running else { return }
        running = true

        if barometerAvailable {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                // Delivered to `.main`, so this is already the main thread —
                // `assumeIsolated` just tells the compiler what we know.
                MainActor.assumeIsolated {
                    // Core Motion reports kilopascals; the rest speaks hPa.
                    self?.stationPressure = data.pressure.doubleValue * 10
                }
            }
        }

        if authorization == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()
    }

    func stop() {
        guard running else { return }
        running = false
        altimeter.stopRelativeAltitudeUpdates()
        locationManager.stopUpdatingLocation()
    }

    /// Keeps the fixes — and with them the process, and so the barometer —
    /// coming after the app leaves the screen. Only ever on during a trip, so
    /// the blue indicator is always something the user asked for.
    func setBackgroundUpdates(_ enabled: Bool) {
        locationManager.allowsBackgroundLocationUpdates = enabled
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = enabled
        locationManager.pausesLocationUpdatesAutomatically = !enabled
        #endif
    }

    // MARK: Derived state

    /// How much of the location fix we trust, as a 0–3 step for the signal bars.
    var fixQuality: Int {
        guard let horizontalAccuracy, horizontalAccuracy > 0, lastFix != nil else { return 0 }
        switch horizontalAccuracy {
        case ..<8: return 3
        case ..<25: return 2
        default: return 1
        }
    }

    var locationDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    // MARK: Delegate plumbing

    fileprivate func ingest(_ location: CLLocation) {
        lastFix = location.timestamp

        if location.verticalAccuracy > 0 {
            gpsAltitude = location.altitude
            verticalAccuracy = location.verticalAccuracy
        }
        if location.horizontalAccuracy > 0 {
            horizontalAccuracy = location.horizontalAccuracy
        }
        // A negative speed means the fix could not determine one; showing zero
        // would be a lie, so the readout goes blank instead.
        groundSpeed = location.speed >= 0 ? location.speed : nil
        course = location.course >= 0 ? location.course : nil
    }

    fileprivate func ingest(_ status: CLAuthorizationStatus) {
        authorization = status
        if status == .authorizedWhenInUse || status == .authorizedAlways, running {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: Previews

    #if DEBUG
    /// Canned readings, so the dashboard can be designed in Xcode's canvas
    /// without a device, a barometer, or a walk outside.
    static func preview(
        pressure: Double? = 964.8,
        gpsAltitude: Double? = 428.0,
        speed: Double? = 11.8,
        course: Double? = 47
    ) -> SensorEngine {
        let engine = SensorEngine()
        engine.stationPressure = pressure
        engine.gpsAltitude = gpsAltitude
        engine.groundSpeed = speed
        engine.course = course
        engine.horizontalAccuracy = 5
        engine.verticalAccuracy = 8
        engine.authorization = .authorizedWhenInUse
        engine.lastFix = Date()
        return engine
    }
    #endif

    /// `CLLocationManagerDelegate` is an Objective-C protocol, so it needs a real
    /// `NSObject`. Keeping it separate leaves `SensorEngine` a plain observable.
    ///
    /// The conformance is `@preconcurrency` because `CLLocationManager` predates
    /// actor isolation: it calls back on the queue it was created on, which for
    /// us is always the main one, but the protocol cannot express that.
    @MainActor
    private final class LocationProxy: NSObject, @preconcurrency CLLocationManagerDelegate {
        unowned let engine: SensorEngine

        init(engine: SensorEngine) {
            self.engine = engine
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            engine.ingest(location)
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            engine.ingest(manager.authorizationStatus)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // A dropped fix is normal indoors. The stale-reading styling in the
            // UI already communicates it, so there is nothing to do here.
        }
    }
}
