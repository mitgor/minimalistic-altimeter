import Foundation
import Observation

/// Recorded trips on disk: one JSON file each, newest first in memory.
///
/// ponytail: every trip is loaded whole at launch. Fine for the dozens a person
/// records; switch to summaries-only loading if someone hits hundreds.
@MainActor
@Observable
final class TripStore {
    private(set) var trips: [Trip] = []
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Trips", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        load()
    }

    func save(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        trips.append(trip)
        trips.sort { $0.startedAt > $1.startedAt }
        if let data = try? JSONEncoder().encode(trip) {
            try? data.write(to: url(for: trip.id), options: .atomic)
        }
    }

    func delete(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        try? FileManager.default.removeItem(at: url(for: trip.id))
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    #if DEBUG
    /// A store in a temporary folder with one trip of each kind, for previews
    /// and screenshots.
    static var preview: TripStore {
        let store = TripStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("preview-trips-\(UUID().uuidString)"))
        func trip(_ activity: ActivityType, seconds: Int, daysAgo: Double, _ f: (Double) -> (Double, Double)) -> Trip {
            let start = Date().addingTimeInterval(-daysAgo * 86_400)
            let samples = (0..<seconds).map { i -> TripSample in
                let (alt, speed) = f(Double(i))
                return TripSample(t: Double(i), baro: alt, gps: alt + 3, speed: speed, pressure: 1013.25 * pow(1 - alt / 44_330.8, 5.2559))
            }
            return Trip(startedAt: start, endedAt: start.addingTimeInterval(Double(seconds)), activity: activity, samples: samples)
        }
        // An out-and-back: up to a summit, a pause, and down the same way.
        store.save(trip(.hiking, seconds: 12_600, daysAgo: 1) { t in
            let up = sin(.pi * t / 12_600)
            return (1_254 + 780 * up + sin(t / 210) * 22 + sin(t / 47) * 5, up > 0.985 ? 0 : 1.15 + sin(t / 9) * 0.3)
        })
        store.save(trip(.soaring, seconds: 5_400, daysAgo: 3) { t in
            let phase = t.truncatingRemainder(dividingBy: 600)
            return (1_400 + (phase < 200 ? phase * 2.2 : 440 - (phase - 200) * 0.9) + floor(t / 600) * 30, 24 + sin(t / 40) * 4)
        })
        store.save(trip(.skydiving, seconds: 330, daysAgo: 9) { t in t < 30 ? (4_000, 40) : t < 90 ? (4_000 - (t - 30) * 50, 30) : (1_000 - (t - 90) * 4, 8) })
        store.save(trip(.motorcycle, seconds: 2_700, daysAgo: 12) { t in (420 + sin(t / 300) * 60, 22 + sin(t / 25) * 6) })
        return store
    }
    #endif

    private func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        trips = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Trip.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
