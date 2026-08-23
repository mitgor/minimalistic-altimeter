import SwiftUI

/// A headline number: caption above, numerals and unit on one baseline.
///
/// Left-aligned rather than centred. A column of flush-left readouts scans
/// top-to-bottom in one movement, which is the whole job when you are glancing
/// at this on a handlebar or a summit.
struct Readout: View {
    let caption: String
    let value: String?
    let unit: String
    /// Shown in place of the numerals, saying what is missing rather than
    /// standing in for it. A dash at this size is a slab, and reads as
    /// redacted or half-loaded.
    var placeholder: String
    var size: CGFloat = 76
    var tint: Color = Palette.primary
    var captionTint: Color = Palette.tertiary
    /// Draws a dot before the caption, marking this readout as the one the
    /// derived figures are computed from.
    var marked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if marked {
                    Circle()
                        .fill(captionTint)
                        .frame(width: 4, height: 4)
                }
                Text(caption).captionStyle(captionTint)
            }

            Group {
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value)
                            .font(.readout(size))
                            .foregroundStyle(tint)
                            // Large rounded numerals set a touch tight read as
                            // one object rather than separate glyphs.
                            .tracking(-1.5)
                            .contentTransition(.numericText())

                        Text(unit)
                            .font(.unit(size * 0.26))
                            .foregroundStyle(Palette.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                } else {
                    Text(placeholder)
                        .font(.unit(size * 0.24))
                        .foregroundStyle(Palette.tertiary)
                }
            }
            // The numerals' full height is reserved either way, so nothing
            // below shifts when the first reading lands.
            .frame(height: size * 1.2, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(caption)
        .accessibilityValue(value.map { "\($0) \(unit)" } ?? placeholder)
    }
}

/// The altitude trace behind the readout — 15 minutes of where you have been.
///
/// Deliberately unlabelled: no axes, no grid. Its job is to show the shape of
/// the climb, and the exact numbers are already stated above it.
struct AltitudeTrace: View {
    let samples: [AltitudeTrack.Sample]
    let range: ClosedRange<Double>?
    var tint: Color = Palette.accent

    var body: some View {
        GeometryReader { geometry in
            let points = plot(in: geometry.size)

            ZStack(alignment: .leading) {
                if points.count > 1 {
                    // Fill first so the stroke sits crisply on top of it.
                    filled(points, height: geometry.size.height)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.22), tint.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    line(points)
                        .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                    if let last = points.last {
                        Circle()
                            .fill(tint)
                            .frame(width: 5, height: 5)
                            .position(last)
                    }
                } else {
                    // A dashed rule reads as "nothing yet" without looking broken.
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .animation(.easeOut(duration: 0.4), value: samples.count)
        .accessibilityHidden(true)
    }

    private func plot(in size: CGSize) -> [CGPoint] {
        guard let range, samples.count > 1,
              let first = samples.first?.time, let last = samples.last?.time else { return [] }

        let span = max(last - first, 1)
        let height = max(range.upperBound - range.lowerBound, 0.001)

        return samples.map { sample in
            CGPoint(
                x: (sample.time - first) / span * size.width,
                y: (1 - (sample.altitude - range.lowerBound) / height) * size.height
            )
        }
    }

    private func line(_ points: [CGPoint]) -> Path {
        Path { path in
            path.move(to: points[0])
            for point in points.dropFirst() { path.addLine(to: point) }
        }
    }

    private func filled(_ points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: points[0].x, y: height))
            for point in points { path.addLine(to: point) }
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: height))
            path.closeSubpath()
        }
    }
}

/// Three bars showing how good the location fix is.
struct FixBars: View {
    let quality: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(step <= quality ? Palette.secondary : Palette.hairline)
                    .frame(width: 2.5, height: 3.5 * CGFloat(step) + 2)
            }
        }
        .animation(.easeOut(duration: 0.3), value: quality)
        .accessibilityLabel("Signal")
        .accessibilityValue("\(quality) of 3")
    }
}

/// The tappable source badge. Also the app's one piece of colour when live.
struct SourcePill: View {
    let label: String
    var isLive: Bool
    var isWarning = false

    private var tint: Color { isWarning ? Palette.accent : (isLive ? Palette.primary : Palette.tertiary) }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isWarning ? Palette.accent : (isLive ? Palette.ascending : Palette.tertiary))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(Palette.surface)
                .overlay(Capsule().stroke(Palette.hairline, lineWidth: 1))
        )
    }
}

/// One cell of the bottom strip: a small figure with its name under it.
struct StatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.detail)
                .foregroundStyle(Palette.primary)
                .contentTransition(.numericText())
            Text(label).captionStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// A hairline the width of the content, used to separate the two heroes.
struct Divider1px: View {
    var body: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(height: 1)
    }
}
