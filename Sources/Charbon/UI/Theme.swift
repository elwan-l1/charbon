import AppKit
import SwiftUI

/// Colours and shapes in the style of the app icon: flat, ink on paper, thick lines, hard edges.
enum Theme {
  static let paper = dynamic(light: 0xF6F6F2, dark: 0x101010)
  static let surface = dynamic(light: 0xFFFFFF, dark: 0x1B1B1B)
  static let ink = dynamic(light: 0x111111, dark: 0xF4F4F0)
  /// The outline of boxes and fields.
  ///
  /// Black on paper, and a softer grey in the dark, where a near white outline glares. It keeps a
  /// contrast of 3 to 1 or more, the minimum for outlines.
  static let line = dynamic(light: 0x111111, dark: 0x868682)
  static let ember = dynamic(light: 0xD93A12, dark: 0xFF6A3D)
  static let good = dynamic(light: 0x0F7A4F, dark: 0x4CC38A)
  static let warn = dynamic(light: 0xA86500, dark: 0xFFC247)
  static let bad = dynamic(light: 0xC41F31, dark: 0xFF6B7A)

  /// Secondary text.
  ///
  /// It keeps a contrast of 4.5 to 1 or more on paper and on surface.
  static let muted = ink.opacity(0.68)
  /// Hints that are not needed to understand the screen.
  static let faint = ink.opacity(0.42)
  static let hairline = ink.opacity(0.16)

  /// The thick line of the icon.
  static let stroke: CGFloat = 2

  private static func dynamic(light: UInt32, dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
      })
  }
}

extension NSColor {
  convenience init(hex: UInt32) {
    self.init(
      srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

extension Font {
  /// Big numbers: heavy and monospaced, like the marks of a dial.
  static func readout(_ size: CGFloat) -> Font {
    .system(size: size, weight: .heavy, design: .monospaced)
  }

  static func figure(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight).monospacedDigit()
  }

  /// A screen title.
  static let title = Font.system(size: 30, weight: .heavy)
  /// The title of a section.
  static let heading = Font.system(size: 18, weight: .heavy)
  /// Text to read.
  static let reading = Font.system(size: 14, weight: .medium)
  static let readingStrong = Font.system(size: 14, weight: .bold)
  /// Supporting text.
  ///
  /// Never smaller than this.
  static let note = Font.system(size: 12.5, weight: .medium)
}

extension Shape {
  /// The fill and the thick outline of a box.
  func outlined(
    fill: Color = Theme.surface,
    line: Color = Theme.line,
    width: CGFloat = Theme.stroke
  ) -> some View {
    ZStack {
      self.fill(fill)
      self.stroke(line, lineWidth: width)
    }
  }
}

extension View {
  /// A flat box with the thick outline of the icon.
  func panel(padding: CGFloat = 18, outline: Color = Theme.line) -> some View {
    self
      .padding(padding)
      .background(Rectangle().outlined(line: outline))
  }

  /// A thin box for what sits inside a panel.
  func softPanel(padding: CGFloat = 12) -> some View {
    self
      .padding(padding)
      .background(
        Rectangle().outlined(fill: Theme.paper, line: Theme.hairline, width: 1.5))
  }
}

/// A small label in capitals above a value.
struct Eyebrow: View {
  let text: String
  var color: Color = Theme.muted

  var body: some View {
    Text(text.uppercased())
      .font(.system(size: 11.5, weight: .heavy))
      .tracking(1.2)
      .foregroundStyle(color)
  }
}

/// A section title with a line of help below it.
struct SectionTitle: View {
  let title: String
  var help: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.heading)
      if let help {
        Text(help).font(.note).foregroundStyle(Theme.muted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

enum BlockButtonKind {
  case primary
  case secondary
  case quiet
}

/// A flat button with square corners.
///
/// It turns ink when pressed.
struct BlockButtonStyle: ButtonStyle {
  var kind: BlockButtonKind = .secondary
  var large = false

  func makeBody(configuration: Configuration) -> some View {
    BlockButtonBody(configuration: configuration, kind: kind, large: large)
  }
}

private struct BlockButtonBody: View {
  let configuration: ButtonStyleConfiguration
  let kind: BlockButtonKind
  let large: Bool
  @State private var isHovering = false
  @Environment(\.isEnabled) private var isEnabled

  var body: some View {
    configuration.label
      .font(.system(size: large ? 15 : 13, weight: .heavy))
      .tracking(large ? 1.2 : 0.4)
      .foregroundStyle(foreground)
      .padding(.horizontal, large ? 32 : 16)
      .padding(.vertical, large ? 17 : 9)
      .background(
        Rectangle().outlined(fill: face, line: line)
      )
      .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
      .opacity(isEnabled ? 1 : 0.4)
      .contentShape(Rectangle())
      .onHover { isHovering = $0 && isEnabled }
  }

  private var isPressed: Bool {
    configuration.isPressed && isEnabled
  }

  private var isActive: Bool {
    isHovering || isPressed
  }

  private var foreground: Color {
    switch kind {
    case .primary: Theme.paper
    case .secondary, .quiet: isPressed ? Theme.paper : Theme.ink
    }
  }

  private var face: Color {
    switch kind {
    case .primary: isActive ? Theme.ember : Theme.ink
    case .secondary: isPressed ? Theme.ink : (isHovering ? Theme.paper : Theme.surface)
    case .quiet: isPressed ? Theme.ink : (isHovering ? Theme.surface : .clear)
    }
  }

  private var line: Color {
    switch kind {
    case .quiet: return isActive ? Theme.line : .clear
    case .secondary: return Theme.line
    case .primary: return isActive ? Theme.ember : Theme.ink
    }
  }
}

extension ButtonStyle where Self == BlockButtonStyle {
  static var block: BlockButtonStyle { BlockButtonStyle() }
  static var blockPrimary: BlockButtonStyle { BlockButtonStyle(kind: .primary) }
  static var blockQuiet: BlockButtonStyle { BlockButtonStyle(kind: .quiet) }
  static var blockHero: BlockButtonStyle { BlockButtonStyle(kind: .primary, large: true) }
}
