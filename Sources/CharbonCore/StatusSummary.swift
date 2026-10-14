import Foundation

/// The text the menu shows about today and this week.
package struct StatusSummary: Equatable, Sendable {
  package var headline: String
  package var lines: [String]

  package static func make(snapshot: WeekSnapshot, now: ClockTime) -> StatusSummary {
    let headline =
      switch snapshot.status {
      case .notStarted: "Not clocked in yet"
      case .working(let since): "Clocked in since \(since)"
      case .stopped(let end): "Clocked out at \(end)"
      }
    return StatusSummary(
      headline: headline,
      lines: [
        line(
          "Today", worked: snapshot.todayWorkedMinutes(now: now),
          target: snapshot.todayTargetMinutes),
        line(
          "This week", worked: snapshot.weekWorkedMinutes(now: now),
          target: snapshot.weekTargetMinutes),
      ]
    )
  }

  private static func line(_ title: String, worked: Int, target: Int?) -> String {
    var text = "\(title): \(HoursValue(minutes: worked).formatted)"
    if let target, target > 0 {
      text += " of \(HoursValue(minutes: target).formatted)"
    }
    return text
  }
}
