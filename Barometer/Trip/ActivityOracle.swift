import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
@Generable
private struct ActivityGuess {
    @Guide(description: "One of: hiking, motorcycle, skydiving, soaring, other")
    var activity: String
    @Guide(description: "Confidence from 0 to 1")
    var confidence: Double
}
#endif

/// A second opinion on the activity from the on-device language model.
///
/// It only ever sees the same summary the rules see, so it cannot know more —
/// but it can weigh the numbers together where a rule has a hard edge. It runs
/// only on iOS 26 with Apple Intelligence, and only overrides a guess when it is
/// sure; anything else keeps the rules' answer.
enum ActivityOracle {
    static func refine(_ trip: Trip) async -> ActivityType? {
        #if canImport(FoundationModels)
        guard #available(iOS 26, *) else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let s = TripSummary(trip)
        let prompt = """
        Classify a recorded outdoor trip from these figures. Duration \(Int(s.duration)) s, \
        moving time \(Int(s.movingTime)) s, distance \(Int(s.distance)) m, \
        average moving speed \(s.averageMovingSpeed.map { String(format: "%.1f", $0) } ?? "unknown") m/s, \
        max speed \(String(format: "%.1f", s.maxSpeed)) m/s, ascent \(Int(s.ascent)) m, descent \(Int(s.descent)) m, \
        altitude range \(Int((s.maxAltitude ?? 0) - (s.minAltitude ?? 0))) m, \
        max climb rate \(String(format: "%.1f", s.maxClimb)) m/s, max sink rate \(String(format: "%.1f", s.maxSink)) m/s, \
        seconds in freefall \(Int(s.freefallTime)), sustained climbs \(s.climbs). \
        Activities: hiking (walking pace), motorcycle (road speeds, little climb), \
        skydiving (freefall then canopy), soaring (glider or paraglider: sustained climbs at flying speed).
        """
        do {
            let session = LanguageModelSession(instructions: "You classify outdoor activities from motion statistics. Answer with the single best activity.")
            let guess = try await session.respond(to: prompt, generating: ActivityGuess.self).content
            guard guess.confidence >= 0.8, let type = ActivityType(rawValue: guess.activity.lowercased()) else { return nil }
            return type
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
