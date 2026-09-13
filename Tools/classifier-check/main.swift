// Runs the activity classifier over four synthetic tracks, one per activity.
//
//   swiftc Shared/Core/Trip.swift Tools/classifier-check/main.swift -o /tmp/cc && /tmp/cc
import Foundation

func trip(seconds: Int, _ f: (Double) -> (alt: Double, speed: Double)) -> Trip {
    let samples = (0..<seconds).map { i -> TripSample in
        let p = f(Double(i)); return TripSample(t: Double(i), baro: p.alt, gps: nil, speed: p.speed, pressure: nil)
    }
    return Trip(startedAt: Date(), endedAt: Date().addingTimeInterval(Double(seconds)), activity: .other, samples: samples)
}

// A walk: 1.3 m/s up a steady 8 % grade with a little noise.
let hike = trip(seconds: 3600) { t in (1000 + t * 0.1 + sin(t) * 0.3, 1.3) }
// A ride: 25 m/s along a road that rolls a little.
let ride = trip(seconds: 1800) { t in (400 + sin(t / 200) * 40, 25 + sin(t / 30) * 3) }
// A jump: 60 s of freefall at 50 m/s from 4000 m, then 4 minutes under canopy.
let jump = trip(seconds: 330) { t in
    t < 30 ? (4000, 40) : t < 90 ? (4000 - (t - 30) * 50, 30) : (1000 - (t - 90) * 4, 8)
}
// A glide: three 3-minute thermals at 2 m/s between long glides at 25 m/s.
let glide = trip(seconds: 3600) { t in
    let phase = t.truncatingRemainder(dividingBy: 600)
    return (1200 + (phase < 180 ? phase * 2 : 360 - (phase - 180) * 0.8) + floor(t / 600) * 20, 25)
}

let results = [(hike, ActivityType.hiking), (ride, .motorcycle), (jump, .skydiving), (glide, .soaring)]
    .map { (ActivityClassifier.classify(TripSummary($0)), $1) }
for (got, want) in results { print(got == want ? "ok  " : "FAIL", want, "->", got) }
precondition(results.allSatisfy { $0 == $1 }, "classifier check failed")
