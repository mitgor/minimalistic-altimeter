import SwiftUI

/// A headline number: caption above, numerals and unit on one baseline.
///
/// Left-aligned rather than centred. A column of flush-left readouts scans
/// top-to-bottom in one movement, which is the whole job when you are glancing
/// at this on a handlebar or a summit.
struct Readout: View {
    @Environment(\.theme) private var theme
    let caption: String
    let value: String?
    let unit: String
    /// Shown in place of the numerals, saying what is missing rather than
    /// standing in for it. A dash at this size is a slab, and reads as
    /// redacted or half-loaded.
    var placeholder: String
    var size: CGFloat = 76
    var tint: Color? = nil
    var captionTint: Color? = nil
    /// Draws a dot before the caption, marking this readout as the one the
    /// derived figures are computed from.
    var marked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if marked {
                    Circle()
                        .fill(captionTint ?? theme.tertiary)
                        .frame(width: 4, height: 4)
                }
                Text(caption).captionStyle(captionTint)
            }

            Group {
                if let value {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value)
                            .font(theme.readout(size))
                            .foregroundStyle(tint ?? theme.primary)
                            .tracking(theme.readoutTracking)
                            .contentTransition(.numericText())

                        Text(unit)
                            .font(theme.unit(size * 0.26))
                            .foregroundStyle(theme.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                } else {
                    Text(placeholder)
                        .font(theme.unit(size * 0.24))
                        .foregroundStyle(theme.tertiary)
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
    @Environment(\.theme) private var theme
    let samples: [AltitudeTrack.Sample]
    let range: ClosedRange<Double>?
    var tint: Color? = nil

    var body: some View {
        let tint = tint ?? theme.accent

        GeometryReader { geometry in
            let points = plot(in: geometry.size)

            ZStack(alignment: .leading) {
                if points.count > 1 {
                    switch theme.traceStyle {
                    case .line: line(points, tint: tint, size: geometry.size)
                    case .dots: dots(points, tint: tint, size: geometry.size)
                    case .bars: bars(points, tint: tint, size: geometry.size)
                    }
                } else if theme.cellStyle != .boxed {
                    // A rule reads as "nothing yet" without looking broken.
                    // A boxed trace already has a frame saying the same.
                    Rectangle()
                        .fill(theme.hairline)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .overlay {
            if theme.cellStyle == .boxed {
                Rectangle().stroke(theme.hairline, lineWidth: 1)
            }
        }
        .animation(.easeOut(duration: 0.4), value: samples.count)
        .accessibilityHidden(true)
    }

    // MARK: Renderers

    private func line(_ points: [CGPoint], tint: Color, size: CGSize) -> some View {
        ZStack {
            // Fill first so the stroke sits crisply on top of it.
            filled(points, height: size.height)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.22), tint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            stroke(points)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            if let last = points.last {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .position(last)
            }
        }
    }

    /// A dot matrix: the curve is the top dot of each column, and the column
    /// beneath it glows faintly, the way a phosphor grid fills in under a plot.
    private func dots(_ points: [CGPoint], tint: Color, size: CGSize) -> some View {
        Canvas { context, _ in
            let pitch: CGFloat = 4
            let dot = CGSize(width: 2, height: 2)
            let columns = Int(size.width / pitch)
            let rows = Int(size.height / pitch)

            for column in 0...columns {
                let x = CGFloat(column) * pitch
                let top = Int((height(at: x, in: points) / pitch).rounded())
                for row in 0...rows {
                    let y = CGFloat(row) * pitch
                    let opacity = row < top ? 0.08 : (row == top ? 1 : 0.4)
                    let rect = CGRect(origin: CGPoint(x: x, y: y), size: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(opacity)))
                }
            }
        }
    }

    /// Solid bars up to the curve, one segment per column — a bar histogram
    /// is what a monochrome LCD can actually draw.
    private func bars(_ points: [CGPoint], tint: Color, size: CGSize) -> some View {
        Canvas { context, _ in
            let pitch: CGFloat = 3
            let columns = Int(size.width / pitch)

            for column in 0...columns {
                let x = CGFloat(column) * pitch
                let y = height(at: x, in: points)
                let rect = CGRect(x: x, y: y, width: pitch - 1, height: size.height - y)
                context.fill(Path(rect), with: .color(tint))
            }
        }
    }

    // MARK: Geometry

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

    /// The curve's y at an arbitrary x, linearly interpolated between samples.
    private func height(at x: CGFloat, in points: [CGPoint]) -> CGFloat {
        guard let next = points.firstIndex(where: { $0.x >= x }) else { return points[points.count - 1].y }
        guard next > 0 else { return points[0].y }
        let a = points[next - 1], b = points[next]
        let t = b.x == a.x ? 0 : (x - a.x) / (b.x - a.x)
        return a.y + (b.y - a.y) * t
    }

    private func stroke(_ points: [CGPoint]) -> Path {
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
    @Environment(\.theme) private var theme
    let quality: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(step <= quality ? theme.secondary : theme.hairline)
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
    @Environment(\.theme) private var theme
    let label: String
    var isLive: Bool
    var isWarning = false

    private var tint: Color { isWarning ? theme.accent : (isLive ? theme.primary : theme.tertiary) }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isWarning ? theme.accent : (isLive ? theme.ascending : theme.tertiary))
                .frame(width: 5, height: 5)
            Text(label)
                .font(theme.caption)
                .tracking(1.2)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius == 0 ? 0 : 99)
                .fill(theme.surface)
                .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius == 0 ? 0 : 99).stroke(theme.hairline, lineWidth: 1))
        )
    }
}

/// One cell of the bottom strip: a small figure with its name under it.
struct StatCell: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(theme.detail)
                .foregroundStyle(theme.primary)
                .contentTransition(.numericText())
            Text(label).captionStyle()
        }
        // Four abreast on a narrow phone: shrink before wrapping, since a
        // wrapped figure reads as two figures.
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, theme.cellStyle == .flat ? 0 : 8)
        .padding(.horizontal, theme.cellStyle == .flat ? 0 : 7)
        .background {
            // Flat cells lean on the rule above them; tiles and boxes carry
            // their own frame instead.
            switch theme.cellStyle {
            case .flat: EmptyView()
            case .tiles:
                RoundedRectangle(cornerRadius: theme.cornerRadius)
                    .fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.hairline, lineWidth: 1))
            case .boxed:
                Rectangle().stroke(theme.hairline, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

/// A hairline the width of the content, used to separate the two heroes.
struct Divider1px: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
    }
}
