import CharbonCore
import SwiftUI

/// The three looks of the window, each drawn small so the user sees what they get.
struct AppearanceChoice: View {
  @Bindable var model: SettingsModel

  var body: some View {
    HStack(spacing: 12) {
      ForEach(AppearanceMode.allCases, id: \.self) { mode in
        ChoiceCard(
          title: mode.title,
          isSelected: model.settings.appearance == mode,
          action: { model.settings.appearance = mode },
          content: { MiniWindow(mode: mode).frame(height: 92) }
        )
      }
    }
  }
}

private struct MiniPalette {
  let paper: Color
  let surface: Color
  let ink: Color

  static let light = MiniPalette(
    paper: Color(nsColor: NSColor(hex: 0xF6F6F2)),
    surface: Color(nsColor: NSColor(hex: 0xFFFFFF)),
    ink: Color(nsColor: NSColor(hex: 0x111111))
  )
  static let dark = MiniPalette(
    paper: Color(nsColor: NSColor(hex: 0x101010)),
    surface: Color(nsColor: NSColor(hex: 0x1B1B1B)),
    ink: Color(nsColor: NSColor(hex: 0xF4F4F0))
  )
}

/// A tiny drawing of the Today screen.
///
/// It uses fixed colours, so it looks the same in any mode.
struct MiniWindow: View {
  let mode: AppearanceMode

  var body: some View {
    Canvas { context, size in
      switch mode {
      case .light:
        Self.draw(&context, size, .light)
      case .dark:
        Self.draw(&context, size, .dark)
      case .system:
        Self.draw(&context, size, .light)
        var corner = Path()
        corner.move(to: CGPoint(x: size.width, y: 0))
        corner.addLine(to: CGPoint(x: size.width, y: size.height))
        corner.addLine(to: CGPoint(x: size.width * 0.25, y: size.height))
        corner.closeSubpath()
        context.clip(to: corner)
        Self.draw(&context, size, .dark)
      }
    }
    .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1.5))
  }

  private static func draw(_ context: inout GraphicsContext, _ size: CGSize, _ palette: MiniPalette)
  {
    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.paper))
    let side = CGRect(x: 8, y: 10, width: 26, height: 6)
    context.fill(Path(side), with: .color(palette.ink))
    for row in 1...2 {
      let bar = side.offsetBy(dx: 0, dy: CGFloat(row) * 12)
      context.fill(Path(bar), with: .color(palette.ink.opacity(0.28)))
    }
    let card = CGRect(x: 46, y: 10, width: size.width - 56, height: 42)
    context.fill(Path(card), with: .color(palette.surface))
    context.stroke(Path(card), with: .color(palette.ink), lineWidth: 1.5)
    context.fill(
      Path(CGRect(x: card.minX + 8, y: card.minY + 8, width: 40, height: 10)),
      with: .color(palette.ink))
    context.fill(
      Path(CGRect(x: card.minX + 8, y: card.minY + 28, width: card.width - 16, height: 6)),
      with: .color(palette.ink.opacity(0.22)))
    context.fill(
      Path(CGRect(x: card.minX + 8, y: card.minY + 28, width: (card.width - 16) * 0.6, height: 6)),
      with: .color(palette.ink))
    for column in 0..<3 {
      let tile = CGRect(
        x: card.minX + CGFloat(column) * ((card.width - 8) / 3), y: 60,
        width: (card.width - 16) / 3, height: 22)
      context.stroke(Path(tile), with: .color(palette.ink.opacity(0.5)), lineWidth: 1)
    }
  }
}
