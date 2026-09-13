import Foundation

/// What a trip is for: which numbers matter, and which profile to draw.
enum ActivityType: String, Codable, CaseIterable, Identifiable, Sendable {
    case hiking, motorcycle, skydiving, soaring, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hiking: String(localized: "Hiking")
        case .motorcycle: String(localized: "Motorcycle")
        case .skydiving: String(localized: "Skydiving")
        case .soaring: String(localized: "Soaring")
        case .other: String(localized: "Other")
        }
    }
}

/// One second of a trip. Times are seconds since the trip started so the file
/// stays small and the maths stays in one unit.
struct TripSample: Codable, Sendable, Equatable {
    var t: Double
    var baro: Double?
    var gps: Double?
    var speed: Double?
    var pressure: Double?

    /// The altitude the trip was tracking, barometric first.
    var altitude: Double? { baro ?? gps }
}

/// A recorded trip. Nothing in here says where you were — altitude, speed and
/// pressure only, by design.
struct Trip: Codable, Identifiable, Sendable, Equatable {
    var id = UUID()
    var startedAt: Date
    var endedAt: Date
    var activity: ActivityType
    /// True while the label is the app's guess; a user's choice sticks.
    var activityWasDetected = true
    var samples: [TripSample]

    var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

// MARK: Derived figures

/// Everything the statistics screens and the classifier read, computed once
/// from the samples. Rates are fitted over a window, as on the dashboard, so a
/// single bad fix cannot claim you fell out of the sky.
struct TripSummary: Sendable {
    let duration: TimeInterval
    let movingTime: TimeInterval
    let distance: Double
    let ascent: Double
    let descent: Double
    let maxAltitude: Double?
    let minAltitude: Double?
    let firstAltitude: Double?
    let lastAltitude: Double?
    let maxSpeed: Double
    let averageMovingSpeed: Double?
    /// Metres per second, positive up, fitted over `rateWindow`.
    let maxClimb: Double
    let maxSink: Double
    /// Seconds spent sinking faster than the freefall threshold.
    let freefallTime: TimeInterval
    /// Altitude where a freefall ended, i.e. where a canopy opened.
    let deploymentAltitude: Double?
    /// Sustained climbs — what a glider pilot would call thermals.
    let climbs: Int
    /// Distance covered per metre of net height lost, when height was lost.
    let glideRatio: Double?

    static let rateWindow: Double = 10
    static let freefallSink: Double = -25
    /// Below walking pace it is GPS jitter, not travel — same rule as the dashboard.
    static let movingSpeed: Double = 0.5
    /// A barometer's noise floor; smaller steps are weather, not climbing.
    static let gainThreshold: Double = 2

    init(_ trip: Trip) {
        let s = trip.samples
        duration = trip.duration

        var moving = 0.0, dist = 0.0, top = 0.0
        for i in 1..<max(s.count, 1) {
            let dt = s[i].t - s[i - 1].t
            if let v = s[i].speed {
                top = max(top, v)
                if v > Self.movingSpeed { moving += dt; dist += v * dt }
            }
        }
        movingTime = moving; distance = dist; maxSpeed = top
        averageMovingSpeed = moving > 3 ? dist / moving : nil

        let alts = s.compactMap { p -> (Double, Double)? in p.altitude.map { (p.t, $0) } }
        maxAltitude = alts.map(\.1).max()
        minAltitude = alts.map(\.1).min()
        firstAltitude = alts.first?.1
        lastAltitude = alts.last?.1

        // Ascent and descent with a pivot, as on the dashboard.
        var up = 0.0, down = 0.0, pivot = alts.first?.1
        for (_, a) in alts {
            guard let p = pivot else { continue }
            let d = a - p
            if abs(d) >= Self.gainThreshold { if d > 0 { up += d } else { down -= d }; pivot = a }
        }
        ascent = up; descent = down

        // Vertical rate series: slope over the trailing window.
        var rates: [(Double, Double)] = []
        var start = 0
        for j in alts.indices {
            while alts[j].0 - alts[start].0 > Self.rateWindow { start += 1 }
            let span = alts[j].0 - alts[start].0
            if span >= Self.rateWindow * 0.6, j > start {
                rates.append((alts[j].0, (alts[j].1 - alts[start].1) / span))
            }
        }
        maxClimb = rates.map(\.1).max() ?? 0
        maxSink = rates.map(\.1).min() ?? 0

        var freefall = 0.0, deploy: Double? = nil, inFreefall = false
        var climbCount = 0, climbSince: Double? = nil
        for k in rates.indices {
            let (t, r) = rates[k]
            let dt = k > 0 ? t - rates[k - 1].0 : 0
            if r < Self.freefallSink { freefall += dt; inFreefall = true }
            else if inFreefall, r > Self.freefallSink * 0.6 {
                inFreefall = false
                deploy = alts.last { $0.0 <= t }?.1
            }
            if r > 0.5 { climbSince = climbSince ?? t }
            else if let since = climbSince { if t - since >= 30 { climbCount += 1 }; climbSince = nil }
        }
        freefallTime = freefall; deploymentAltitude = deploy; climbs = climbCount

        if let f = firstAltitude, let l = lastAltitude, f - l > 50, dist > 0 {
            glideRatio = dist / (f - l)
        } else {
            glideRatio = nil
        }
    }
}

// MARK: Classification

/// Picks an activity from the track's signature. Rules, not learning: each
/// activity has a physical tell that no other one shares, and a rule can be
/// read and argued with.
enum ActivityClassifier {
    static func classify(_ summary: TripSummary) -> ActivityType {
        let range = (summary.maxAltitude ?? 0) - (summary.minAltitude ?? 0)

        // Nothing else sinks at 25 m/s and lives to tell about it.
        if summary.freefallTime >= 5, range > 500 { return .skydiving }

        // Climbing without an engine leaves a trace of sustained lifts, at
        // speeds a hiker cannot reach and a motorcyclist cannot climb at.
        if summary.climbs >= 1, summary.maxClimb >= 1.5, range >= 300,
           let v = summary.averageMovingSpeed, v >= 6, v <= 50 {
            return .soaring
        }

        if let v = summary.averageMovingSpeed {
            if v >= 12 || summary.maxSpeed >= 25 { return .motorcycle }
            if v < 2.5, summary.movingTime >= 120 { return .hiking }
        }
        return .other
    }
}
