import SwiftUI

/// The mark of the app icon, drawn from its source: a lump of coal with the face of a clock.
struct LogoMark: View {
  var size: CGFloat = 32
  var color: Color = Theme.ink

  // The box of the art inside the 1024 point source, and its centre.
  private static let artSize: CGFloat = 700
  private static let center = CGPoint(x: 507, y: 522)

  private static let lump: [CGPoint] = [
    CGPoint(x: 375.375, y: 250.438), CGPoint(x: 638.375, y: 234),
    CGPoint(x: 802.75, y: 414.812), CGPoint(x: 737, y: 710.688),
    CGPoint(x: 506.875, y: 809.312), CGPoint(x: 276.75, y: 710.688),
    CGPoint(x: 211, y: 447.688),
  ]

  // Each tick is a start and an end.
  private static let ticks: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 501, y: 675), CGPoint(x: 501, y: 745)),
    (CGPoint(x: 501, y: 296), CGPoint(x: 501, y: 366)),
    (CGPoint(x: 649, y: 530), CGPoint(x: 719, y: 530)),
    (CGPoint(x: 289, y: 530), CGPoint(x: 359, y: 530)),
    (CGPoint(x: 636.393, y: 398.393), CGPoint(x: 671.749, y: 363.038)),
    (CGPoint(x: 360.393, y: 673.749), CGPoint(x: 395.749, y: 638.394)),
    (CGPoint(x: 652.96, y: 664.75), CGPoint(x: 617.6, y: 629.4)),
    (CGPoint(x: 390.96, y: 419.75), CGPoint(x: 355.6, y: 384.4)),
  ]

  private static let hands: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 493.501, y: 545), CGPoint(x: 637.001, y: 450.499)),
    (CGPoint(x: 523, y: 546.5), CGPoint(x: 422.501, y: 466)),
  ]

  var body: some View {
    Canvas { context, canvasSize in
      let scale = min(canvasSize.width, canvasSize.height) / Self.artSize
      context.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
      context.scaleBy(x: scale, y: scale)
      context.translateBy(x: -Self.center.x, y: -Self.center.y)

      var outline = Path()
      outline.addLines(Self.lump)
      outline.closeSubpath()
      context.stroke(
        outline,
        with: .color(color),
        style: StrokeStyle(lineWidth: 60, lineCap: .round, lineJoin: .round)
      )
      for (start, end) in Self.ticks {
        context.stroke(
          line(start, end), with: .color(color), style: StrokeStyle(lineWidth: 30, lineCap: .butt))
      }
      for (start, end) in Self.hands {
        context.stroke(
          line(start, end), with: .color(color), style: StrokeStyle(lineWidth: 50, lineCap: .butt))
      }
    }
    .frame(width: size, height: size)
    .accessibilityLabel("Charbon")
  }

  private func line(_ start: CGPoint, _ end: CGPoint) -> Path {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    return path
  }
}
