import Charts
import SwiftUI

/// One trip's statistics. The activity decides which figures are worth the
/// space and which profile is drawn — a skydiver wants the deployment altitude,
/// a rider wants the speed trace, and neither wants the other's.
struct TripDetailView: View {
    @Environment(\.theme) private var theme
    @State var trip: Trip
    let store: TripStore
    let settings: Settings

    private var summary: TripSummary { TripSummary(trip) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                metrics
                profile(altitude: true)
                if trip.activity == .motorcycle || trip.activity == .other {
                    profile(altitude: false)
                }
            }
            .padding(24)
        }
        .background(theme.background)
        .navigationTitle(Text(trip.startedAt, format: .dateTime.day().month()))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Activity

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity").captionStyle()
            Picker("Activity", selection: $trip.activity) {
                ForEach(ActivityType.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(theme.accent)
            .onChange(of: trip.activity) { _, _ in
                trip.activityWasDetected = false
                store.save(trip)
            }
            Text(trip.activityWasDetected ? "Recognised from the track" : "Set by you")
                .font(theme.caption)
                .foregroundStyle(theme.tertiary)
        }
    }

    // MARK: Figures

    private var metrics: some View {
        let unit = settings.altitudeUnit, speed = settings.speedUnit, s = summary
        let alt = { (m: Double?) -> String in m.map { "\(Format.number(unit.convert($0))) \(unit.symbol)" } ?? String(localized: "No reading") }
        let vel = { (v: Double) -> String in "\(Format.number(speed.convert(v))) \(speed.symbol)" }
        let rate = { (r: Double) -> String in "\(Format.number(unit.convert(r), decimals: 1)) \(unit.symbol)/s" }
        let time = { (t: TimeInterval) -> String in Duration.seconds(t).formatted(.time(pattern: .hourMinuteSecond)) }

        var rows: [(LocalizedStringKey, String)]
        switch trip.activity {
        case .hiking:
            rows = [("Duration", time(s.duration)), ("Moving time", time(s.movingTime)),
                    ("Distance", Format.distance(s.distance, unit: unit)), ("Pace", pace(s)),
                    ("Ascent", Format.distance(s.ascent, unit: unit)), ("Descent", Format.distance(s.descent, unit: unit)),
                    ("Highest", alt(s.maxAltitude)), ("Lowest", alt(s.minAltitude))]
        case .motorcycle:
            rows = [("Duration", time(s.duration)), ("Moving time", time(s.movingTime)),
                    ("Distance", Format.distance(s.distance, unit: unit)), ("Max speed", vel(s.maxSpeed)),
                    ("Average speed", s.averageMovingSpeed.map(vel) ?? String(localized: "No reading")),
                    ("Ascent", Format.distance(s.ascent, unit: unit)),
                    ("Highest", alt(s.maxAltitude)), ("Lowest", alt(s.minAltitude))]
        case .skydiving:
            rows = [("Exit altitude", alt(s.maxAltitude)), ("Deployment", alt(s.deploymentAltitude)),
                    ("Freefall", time(s.freefallTime)), ("Max sink", rate(-s.maxSink)),
                    ("Landing", alt(s.lastAltitude)), ("Total descent", Format.distance(s.descent, unit: unit)),
                    ("Duration", time(s.duration)), ("Max speed", vel(s.maxSpeed))]
        case .soaring:
            rows = [("Flight time", time(s.duration)), ("Highest", alt(s.maxAltitude)),
                    ("Height gained", Format.distance(s.ascent, unit: unit)), ("Thermals", "\(s.climbs)"),
                    ("Max climb", rate(s.maxClimb)), ("Max sink", rate(-s.maxSink)),
                    ("Distance", Format.distance(s.distance, unit: unit)),
                    ("Glide ratio", s.glideRatio.map { "\(Format.number($0, decimals: 1)) : 1" } ?? String(localized: "No reading"))]
        case .other:
            rows = [("Duration", time(s.duration)), ("Distance", Format.distance(s.distance, unit: unit)),
                    ("Ascent", Format.distance(s.ascent, unit: unit)), ("Descent", Format.distance(s.descent, unit: unit)),
                    ("Max speed", vel(s.maxSpeed)), ("Highest", alt(s.maxAltitude))]
        }

        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 16) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                StatCell(label: row.0, value: row.1)
            }
        }
    }

    /// Minutes per kilometre or mile, the way walkers and runners count.
    private func pace(_ s: TripSummary) -> String {
        guard let v = s.averageMovingSpeed, v > 0 else { return String(localized: "No reading") }
        let perUnit = settings.altitudeUnit == .metres ? 1000 / v : 1609.344 / v
        return "\(Int(perUnit / 60)):\(String(format: "%02d", Int(perUnit) % 60)) /\(settings.altitudeUnit == .metres ? "km" : "mi")"
    }

    // MARK: Profile

    /// Altitude or speed against elapsed time, thinned to a few hundred
    /// points — a chart cannot show more, and drawing them costs scroll frames.
    private func profile(altitude: Bool) -> some View {
        let step = max(trip.samples.count / 400, 1)
        let unit = settings.altitudeUnit, speed = settings.speedUnit
        let points: [(Double, Double)] = stride(from: 0, to: trip.samples.count, by: step).compactMap { i in
            let p = trip.samples[i]
            let v = altitude ? p.altitude.map(unit.convert) : p.speed.map(speed.convert)
            return v.map { (p.t / 60, $0) }
        }

        // The fill hangs from the trace's own floor, not from zero — a hike
        // at 1,200 m drawn against sea level is a flat line.
        let floor = points.map(\.1).min() ?? 0

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(altitude ? "Altitude" : "Speed").captionStyle()
                Text(altitude ? unit.symbol : speed.symbol).captionStyle()
            }
            Chart(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(x: .value("Minutes", point.0), yStart: .value("Floor", altitude ? floor : 0), yEnd: .value("Value", point.1))
                    .foregroundStyle(LinearGradient(colors: [theme.accent.opacity(0.25), theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Minutes", point.0), y: .value("Value", point.1))
                    .foregroundStyle(theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(theme.hairline)
                    AxisValueLabel().font(theme.caption).foregroundStyle(theme.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(theme.hairline)
                    AxisValueLabel().font(theme.caption).foregroundStyle(theme.tertiary)
                }
            }
            .frame(height: 160)
        }
    }
}
