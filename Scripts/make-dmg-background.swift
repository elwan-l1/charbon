import AppKit

// Draws the background of the disk image window in the style of the app icon: flat, black and
// white, hard edges. A zigzag arrow from the app to the Applications folder, and a low-poly flame
// above it.
//
// Usage: swift Scripts/make-dmg-background.swift <output directory> [white|black]
//
// The background is white because Finder draws the icon names in black on any window that has a
// background picture, in light and in dark mode alike. A black background hides them.
//
// The icon positions in Scripts/release/dmg-settings.py must match the ones below.

// The window shows 660 x 400 points under its title bar. The picture is 20 points taller, so
// that a title bar thinner than expected crops empty space instead of showing a blank strip.
let size = CGSize(width: 660, height: 420)
let centerY: CGFloat = 232
let appCenter = CGPoint(x: 165, y: centerY)
let applicationsCenter = CGPoint(x: 495, y: centerY)

struct Theme {
  let background: CGColor
  let ink: NSColor

  static let black = Theme(
    background: CGColor(gray: 0.07, alpha: 1), ink: NSColor(white: 0.96, alpha: 1))
  static let white = Theme(
    background: CGColor(gray: 0.97, alpha: 1), ink: NSColor(white: 0.07, alpha: 1))
}

func makeContext(scale: CGFloat) -> CGContext {
  let context = CGContext(
    data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  // Draw in points, with the origin at the top left.
  context.translateBy(x: 0, y: size.height * scale)
  context.scaleBy(x: scale, y: -scale)
  return context
}

/// A closed shape from points in a box that is 1 wide and 1 high.
func polygon(_ points: [(CGFloat, CGFloat)], in box: CGRect) -> CGPath {
  let path = CGMutablePath()
  for (index, point) in points.enumerated() {
    let moved = CGPoint(x: box.minX + point.0 * box.width, y: box.minY + point.1 * box.height)
    if index == 0 {
      path.move(to: moved)
    } else {
      path.addLine(to: moved)
    }
  }
  path.closeSubpath()
  return path
}

func fill(_ context: CGContext, _ path: CGPath, red: CGFloat, green: CGFloat, blue: CGFloat) {
  context.setFillColor(CGColor(red: red, green: green, blue: blue, alpha: 1))
  context.addPath(path)
  context.fillPath()
}

func render(scale: CGFloat, theme: Theme) -> CGImage {
  let context = makeContext(scale: scale)
  context.setFillColor(theme.background)
  context.fill(CGRect(origin: .zero, size: size))

  // The arrow: straight lines with square ends, two sharp bends in the shaft and a sharp
  // mitered point, like the tick marks of the icon. The head follows the last stretch.
  let start = CGPoint(x: appCenter.x + 95, y: centerY)
  let peak = CGPoint(x: start.x + 40, y: centerY - 13)
  let valley = CGPoint(x: start.x + 88, y: centerY + 13)
  let tip = CGPoint(x: applicationsCenter.x - 91, y: centerY - 2)
  context.setStrokeColor(theme.ink.cgColor)
  context.setLineWidth(9)
  context.setLineCap(.butt)
  context.setLineJoin(.miter)
  context.setMiterLimit(12)
  context.move(to: start)
  context.addLine(to: peak)
  context.addLine(to: valley)
  context.addLine(to: tip)
  context.strokePath()
  let heading = atan2(tip.y - valley.y, tip.x - valley.x)
  let barb: CGFloat = 30
  let spread: CGFloat = 0.78
  context.move(
    to: CGPoint(x: tip.x - barb * cos(heading - spread), y: tip.y - barb * sin(heading - spread)))
  context.addLine(to: tip)
  context.addLine(
    to: CGPoint(x: tip.x - barb * cos(heading + spread), y: tip.y - barb * sin(heading + spread)))
  context.strokePath()

  // The flame above the middle of the arrow, cut from a few flat facets with sharp tips.
  let box = CGRect(
    x: (appCenter.x + applicationsCenter.x) / 2 - 36, y: centerY - 147, width: 72, height: 100)
  let outline: [(CGFloat, CGFloat)] = [
    (0.50, 0.00), (0.68, 0.30), (0.86, 0.18), (0.94, 0.60), (0.74, 0.92), (0.50, 1.00),
    (0.26, 0.92), (0.06, 0.62), (0.14, 0.28), (0.34, 0.48),
  ]
  let rightHalf: [(CGFloat, CGFloat)] = [
    (0.50, 0.00), (0.68, 0.30), (0.86, 0.18), (0.94, 0.60), (0.74, 0.92), (0.50, 1.00),
    (0.50, 0.50),
  ]
  let inner: [(CGFloat, CGFloat)] = [
    (0.50, 0.34), (0.70, 0.62), (0.62, 0.86), (0.50, 0.94), (0.38, 0.86), (0.30, 0.62),
  ]
  let core: [(CGFloat, CGFloat)] = [(0.50, 0.58), (0.62, 0.76), (0.50, 0.90), (0.38, 0.76)]
  fill(context, polygon(outline, in: box), red: 1.0, green: 0.46, blue: 0.0)
  fill(context, polygon(rightHalf, in: box), red: 0.86, green: 0.27, blue: 0.0)
  fill(context, polygon(inner, in: box), red: 1.0, green: 0.70, blue: 0.08)
  fill(context, polygon(core, in: box), red: 1.0, green: 0.92, blue: 0.45)

  // Short ticks beside the flame, like the ones around the clock of the icon.
  context.setStrokeColor(CGColor(red: 1.0, green: 0.46, blue: 0.0, alpha: 1))
  context.setLineWidth(5)
  context.setLineCap(.butt)
  for (from, to) in [
    (CGPoint(x: 276, y: centerY - 107), CGPoint(x: 262, y: centerY - 115)),
    (CGPoint(x: 384, y: centerY - 107), CGPoint(x: 398, y: centerY - 115)),
    (CGPoint(x: 330, y: centerY - 161), CGPoint(x: 330, y: centerY - 175)),
  ] {
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
  }

  return context.makeImage()!
}

func write(_ image: CGImage, to url: URL, dpi: Double) {
  let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
  CGImageDestinationAddImage(
    destination, image,
    [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
  guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(url.path)")
  }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 || arguments.count == 3 else {
  FileHandle.standardError.write(
    Data("usage: make-dmg-background.swift <directory> [white|black]\n".utf8))
  exit(2)
}
let theme = arguments.count == 3 && arguments[2] == "black" ? Theme.black : Theme.white
let directory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
write(
  render(scale: 1, theme: theme), to: directory.appendingPathComponent("background.png"), dpi: 72)
write(
  render(scale: 2, theme: theme), to: directory.appendingPathComponent("background@2x.png"),
  dpi: 144)
print("Wrote \(directory.path)/background.png and background@2x.png")
