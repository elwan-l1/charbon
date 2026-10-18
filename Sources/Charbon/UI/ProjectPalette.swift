import SwiftUI

/// Gives every project its own colour, the same one on every screen and after every launch.
@MainActor
enum ProjectPalette {
  private static let key = "projectColors.v1"
  private static let colors: [Color] = [
    dynamic(0x2F5BEA, 0x7C9BFF),
    dynamic(0xE8451E, 0xFF7A52),
    dynamic(0x0E9F8E, 0x3CD2C0),
    dynamic(0xD99A00, 0xFFC247),
    dynamic(0x8E4EC6, 0xB98AF0),
    dynamic(0xD6336C, 0xFF7EA8),
    dynamic(0x5E8C1F, 0xA6CF5A),
  ]

  private static var assigned: [String: Int] = {
    UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
  }()

  /// The colour of a project, given as `projectId/activityId`.
  static func color(for id: String) -> Color {
    if let index = assigned[id] {
      return colors[index % colors.count]
    }
    let index = assigned.count
    assigned[id] = index
    UserDefaults.standard.set(assigned, forKey: key)
    return colors[index % colors.count]
  }

  private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      nsColor: NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return NSColor(hex: isDark ? dark : light)
      })
  }
}
