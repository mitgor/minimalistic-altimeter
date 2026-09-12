import Foundation

/// A rolling window of altitude samples.
///
/// It backs three things at once: the trace behind the altitude readout, the
/// vertical-speed figure, and the cumulative ascent/descent totals. Keeping them
/// in one place means they can never disagree with each other.
struct AltitudeTrack {

    struct Sample: Equatable {
        let time: TimeInterval
        let altitude: Double
    }

    /// How much history the trace keeps.
    static let window: TimeInterval = 15 * 60

    /// Vertical speed is fitted over this much of the recent past. Short enough
    /// to feel live, long enough that sensor noise averages out.
    private static let velocityWindow: TimeInterval = 8

    /// Ascent only counts once you have climbed clear of the sensor's noise
    /// floor, otherwise standing still would accumulate hundreds of metres.
    private static let gainThreshold: Double = 2.0

    private(set) var samples: [Sample] = []
    private(set) var ascent: Double = 0
    private(set) var descent: Double = 0

    /// The last altitude a gain or loss was booked at.
    private var pivot: Double?

    mutating func record(altitude: Double, at time: TimeInterval) {
        // One sample a second is plenty for a 15-minute trace, and keeps the
        // array small enough to redraw every frame without thinking about it.
        if let last = samples.last, time - last.time < 1 {
            return
        }
        samples.append(Sample(time: time, altitude: altitude))

        let cutoff = time - Self.window
        if let first = samples.first, first.time < cutoff {
            samples.removeAll { $0.time < cutoff }
        }

        accumulate(altitude)
    }

    private mutating func accumulate(_ altitude: Double) {
        guard let pivot else {
            self.pivot = altitude
            return
        }
        let delta = altitude - pivot
        guard abs(delta) >= Self.gainThreshold else { return }
        if delta > 0 { ascent += delta } else { descent -= delta }
        self.pivot = altitude
    }

    /// Metres per second, positive climbing.
    ///
    /// Fitted by least squares rather than differencing the last two samples —
    /// a single noisy reading would otherwise swing the number wildly.
    var verticalSpeed: Double? {
        guard let now = samples.last?.time else { return nil }
        let recent = samples.filter { $0.time > now - Self.velocityWindow }
        guard recent.count >= 3, let base = recent.first?.time else { return nil }

        let n = Double(recent.count)
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0
        for sample in recent {
            let x = sample.time - base
            let y = sample.altitude
            sumX += x; sumY += y; sumXY += x * y; sumXX += x * x
        }
        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > .ulpOfOne else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }

    /// Low and high of the visible trace, padded so a flat line sits centred
    /// instead of collapsing onto the baseline.
    var range: ClosedRange<Double>? {
        guard let low = samples.map(\.altitude).min(),
              let high = samples.map(\.altitude).max() else { return nil }
        let padding = max((high - low) * 0.15, 1.5)
        return (low - padding)...(high + padding)
    }

    mutating func reset() {
        samples.removeAll()
        ascent = 0
        descent = 0
        pivot = nil
    }
}
