import Foundation
import Observation
import SwiftUI

/// The single source of truth the dashboard reads from.
///
/// It folds the raw sensor stream and the user's preferences into the handful of
/// numbers actually shown, and keeps the rolling track that sits behind them.
@MainActor
@Observable
final class Instrument {

    let sensors: SensorEngine
    let settings: Settings

    private(set) var track = AltitudeTrack()
    private(set) var topSpeed: Double = 0

    /// Distance travelled, integrated from ground speed rather than from fixes —
    /// it stays honest when the GPS position jitters while you stand still.
    private(set) var distance: Double = 0

    private var movingTime: TimeInterval = 0
    private var lastTick: TimeInterval?
    @ObservationIgnored private var timer: Timer?

    convenience init() {
        self.init(sensors: SensorEngine(), settings: Settings())
    }

    init(sensors: SensorEngine, settings: Settings) {
        self.sensors = sensors
        self.settings = settings
    }

    // MARK: Readings

    /// Altitude in metres from the pressure sensor and the current reference.
    var barometricAltitude: Double? {
        sensors.stationPressure.map {
            Atmosphere.altitude(pressure: $0, seaLevelPressure: settings.referencePressure)
        }
    }

    /// The headline altitude, from whichever source is selected, falling back to
    /// the other one so the number is blank only when both are.
    var altitude: Double? {
        switch settings.altitudeSource {
        case .barometric: barometricAltitude ?? sensors.gpsAltitude
        case .satellite: sensors.gpsAltitude ?? barometricAltitude
        }
    }

    /// True when the selected source had nothing to give and we quietly used the other.
    var isUsingFallbackSource: Bool {
        switch settings.altitudeSource {
        case .barometric: sensors.stationPressure == nil && sensors.gpsAltitude != nil
        case .satellite: sensors.gpsAltitude == nil && sensors.stationPressure != nil
        }
    }

    var effectiveSource: AltitudeSource {
        isUsingFallbackSource
            ? (settings.altitudeSource == .barometric ? .satellite : .barometric)
            : settings.altitudeSource
    }

    /// Plus or minus, in metres, on the headline altitude.
    ///
    /// The barometric figure is quoted against the reference rather than the
    /// sensor: the transducer resolves centimetres, but an uncalibrated QNH can
    /// be tens of metres out, and that is the error worth showing.
    var altitudeAccuracy: Double? {
        // No reading, no error bar on it.
        guard altitude != nil else { return nil }

        // Explicit `return`: with the guard above this is a statement switch,
        // not an expression one.
        switch effectiveSource {
        case .barometric:
            return settings.calibratedAt == nil ? nil : (settings.calibrationIsStale ? 25 : 3)
        case .satellite:
            return sensors.verticalAccuracy
        }
    }

    /// How far the two sources disagree, in metres, when both have a reading.
    ///
    /// With a fresh calibration this sits within a few metres. A large gap means
    /// the reference has gone stale — it is the most honest trust signal the app
    /// has, because unlike the quoted accuracies it is measured, not estimated.
    var divergence: Double? {
        guard let barometricAltitude, let gpsAltitude = sensors.gpsAltitude else { return nil }
        return barometricAltitude - gpsAltitude
    }

    var verticalSpeed: Double? { track.verticalSpeed }

    var speed: Double { sensors.groundSpeed ?? 0 }

    var hasSpeedFix: Bool { sensors.groundSpeed != nil }

    /// `nil` until enough moving time has accrued for the figure to mean
    /// anything — a fraction of a second of history averages to nonsense.
    var averageSpeed: Double? {
        movingTime > 3 ? distance / movingTime : nil
    }

    var heading: String? {
        sensors.course.map(Self.compassPoint)
    }

    // MARK: Lifecycle

    func start() {
        sensors.start()
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake

        timer?.invalidate()
        // 2 Hz keeps the readouts feeling live without redrawing the trace more
        // often than it can possibly change.
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop below, so it always fires there.
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        sensors.stop()
        timer?.invalidate()
        timer = nil
        lastTick = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func tick() {
        let now = Date.timeIntervalSinceReferenceDate

        if let altitude {
            track.record(altitude: altitude, at: now)
        }

        if let groundSpeed = sensors.groundSpeed {
            topSpeed = max(topSpeed, groundSpeed)
            if let lastTick, groundSpeed > 0.5 {
                // Below walking pace it is almost certainly GPS jitter, and
                // counting it would inflate both distance and the average.
                let elapsed = now - lastTick
                distance += groundSpeed * elapsed
                movingTime += elapsed
            }
        }
        lastTick = now
    }

    // MARK: Actions

    /// Solves for the sea-level pressure that puts you at a known altitude.
    @discardableResult
    func calibrate(toAltitude metres: Double) -> Bool {
        guard let stationPressure = sensors.stationPressure else { return false }
        settings.calibrate(
            referencePressure: Atmosphere.seaLevelPressure(
                stationPressure: stationPressure,
                altitude: metres
            )
        )
        track.reset()
        return true
    }

    /// Adopts the GPS altitude as truth and back-solves the reference from it.
    @discardableResult
    func calibrateFromGPS() -> Bool {
        guard let gpsAltitude = sensors.gpsAltitude else { return false }
        return calibrate(toAltitude: gpsAltitude)
    }

    func resetTrip() {
        track.reset()
        topSpeed = 0
        distance = 0
        movingTime = 0
    }

    #if DEBUG
    /// A calibrated instrument part-way up a climb, with a plausible trace.
    static func preview(
        sensors: SensorEngine? = nil,
        calibrated: Bool = true
    ) -> Instrument {
        let sensors = sensors ?? .preview()
        let settings = Settings(defaults: UserDefaults(suiteName: "preview") ?? .standard)
        settings.referencePressure = Atmosphere.standardSeaLevelPressure
        settings.calibratedAt = calibrated ? Date() : nil

        let instrument = Instrument(sensors: sensors, settings: settings)
        let now = Date.timeIntervalSinceReferenceDate
        let base = instrument.altitude ?? 400
        // A climb with a false summit in it — enough shape to judge the trace.
        for step in 0..<420 {
            let progress = Double(step) / 420
            instrument.track.record(
                altitude: base - 90 + progress * 90 + sin(progress * 7) * 11,
                at: now - 420 + Double(step)
            )
        }
        instrument.topSpeed = 19.4
        instrument.distance = 4_820
        return instrument
    }
    #endif

    private static func compassPoint(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees / 45).rounded()) % points.count
        return points[(index + points.count) % points.count]
    }
}
