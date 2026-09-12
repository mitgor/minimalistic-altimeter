import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the app icon: the face of an aircraft altimeter.
//
// The hard part is not looking like a clock. Three things do the work: ten
// graduations rather than twelve, pointers that taper to a point rather than
// rounded bars, and a length ratio between them far more extreme than an hour
// and minute hand. The numerals and warning hatching on a real instrument are
// left out — they turn to mush at tile size.
//
// Usage: MakeIcon <output.png> [scale]. The watch shows icons through a
// circular mask that eats the corners, so it gets the same dial drawn a
// little larger — the bezel sits just inside the circle instead of floating.

let side = 1024.0
let centre = CGPoint(x: side / 2, y: side / 2)

let ink = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
let dim = CGColor(red: 1, green: 1, blue: 1, alpha: 0.30)
let accent = CGColor(red: 1.00, green: 0.62, blue: 0.16, alpha: 1)
let ground = CGColor(red: 0.043, green: 0.043, blue: 0.051, alpha: 1)

guard let context = CGContext(
    data: nil, width: Int(side), height: Int(side),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("context") }

context.setShouldAntialias(true)
context.setFillColor(ground)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

let scale = CommandLine.arguments.dropFirst(2).first.flatMap(Double.init) ?? 1
context.translateBy(x: centre.x, y: centre.y)
context.scaleBy(x: scale, y: scale)
context.translateBy(x: -centre.x, y: -centre.y)

/// Angles run clockwise from twelve o'clock, the way an instrument is read.
func point(_ degrees: Double, _ radius: Double) -> CGPoint {
    let r = degrees * .pi / 180
    return CGPoint(x: centre.x + radius * sin(r), y: centre.y + radius * cos(r))
}

/// A point in the pointer's own frame, before it is swung round to `degrees`.
/// `along` runs out towards the tip, `across` sideways.
func local(_ degrees: Double, along: Double, across: Double) -> CGPoint {
    let r = degrees * .pi / 180
    return CGPoint(
        x: centre.x + across * cos(r) + along * sin(r),
        y: centre.y - across * sin(r) + along * cos(r)
    )
}

func stroke(_ from: CGPoint, _ to: CGPoint, width: Double, color: CGColor) {
    context.setStrokeColor(color)
    context.setLineWidth(width)
    context.setLineCap(.butt)
    context.beginPath()
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
}

/// A pointer that narrows to a point — the shape that separates an instrument
/// needle from a clock hand.
func pointer(_ degrees: Double, reach: Double, halfWidth: Double, color: CGColor) {
    context.setFillColor(color)
    context.beginPath()
    context.move(to: local(degrees, along: reach, across: 0))
    context.addLine(to: local(degrees, along: reach * 0.42, across: halfWidth))
    context.addLine(to: local(degrees, along: -halfWidth, across: halfWidth * 0.62))
    context.addLine(to: local(degrees, along: -halfWidth, across: -halfWidth * 0.62))
    context.addLine(to: local(degrees, along: reach * 0.42, across: -halfWidth))
    context.closePath()
    context.fillPath()
}

// Bezel.
context.setStrokeColor(ink)
context.setLineWidth(34)
context.strokeEllipse(in: CGRect(
    x: centre.x - 428, y: centre.y - 428, width: 856, height: 856
))

// Ten graduations, one per thousand feet. Squared off, not rounded — a dial
// face, not a watch.
for step in 0..<10 {
    let angle = Double(step) * 36
    stroke(point(angle, 320), point(angle, 392), width: 43, color: ink)
}

// One subdivision between each. Five would be correct on the real instrument
// and unreadable here.
for step in 0..<10 {
    let angle = Double(step) * 36 + 18
    stroke(point(angle, 358), point(angle, 392), width: 19, color: dim)
}

// Set to read a little over 1,600 ft. Angling the long pointer up and to the
// right also lets the eye travel the way the instrument is about — and keeps
// the two off a shared axis, where they would read as one needle run through
// the hub.
pointer(22, reach: 320, halfWidth: 29, color: accent)
pointer(118, reach: 194, halfWidth: 42, color: ink)

// Hub, knocked out so the two pointers read as separate parts.
context.setFillColor(ground)
context.fillEllipse(in: CGRect(x: centre.x - 43, y: centre.y - 43, width: 86, height: 86))
context.setStrokeColor(ink)
context.setLineWidth(28)
context.strokeEllipse(in: CGRect(x: centre.x - 43, y: centre.y - 43, width: 86, height: 86))

guard let image = context.makeImage() else { fatalError("image") }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
) else { fatalError("destination") }
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(url.path)")
