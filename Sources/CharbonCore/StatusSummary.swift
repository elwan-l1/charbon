import Foundation

/// The text the menu shows about today and this week.
package struct StatusSummary: Equatable, Sendable {
  package var headline: String
  package var lines: [String]

  /// `dailyHours` replaces the hours of the contract on every day that has some.
  package static func make(
    snapshot: WeekSnapshot,
    now: ClockTime,
    dailyHours: Double? = nil
  ) -> StatusSummary {
    let headline =
      switch snapshot.status {
      case .notStarted: "Not clocked in yet"
      case .working(let since): "Clocked in since \(since)"
      case .stopped(let end): "Clocked out at \(end)"
      }
    let (todayTarget, weekTarget) = targets(snapshot: snapshot, dailyHours: dailyHours)
    var lines = [
      line("Today", worked: snapshot.todayWorkedMinutes(now: now), target: todayTarget),
      line("This week", worked: snapshot.weekWorkedMinutes(now: now), target: weekTarget),
    ]
    let booked = snapshot.todayBookedMinutes
    if booked > 0 {
      lines.append("Booked: \(HoursValue(minutes: booked).formatted)")
    }
    return StatusSummary(headline: headline, lines: lines)
  }

  private static func targets(
    snapshot: WeekSnapshot,
    dailyHours: Double?
  ) -> (today: Int?, week: Int?) {
    guard let dailyHours, dailyHours > 0 else {
      return (snapshot.todayTargetMinutes, snapshot.weekTargetMinutes)
    }
    let daily = Int((dailyHours * 60).rounded())
    func target(_ day: WeekDay) -> Int {
      (day.toDo?.minutes ?? 0) > 0 ? daily : 0
    }
    return (snapshot.today.map(target), snapshot.timesheet.days.reduce(0) { $0 + target($1) })
  }

  private static func line(_ title: String, worked: Int, target: Int?) -> String {
    var text = "\(title): \(HoursValue(minutes: worked).formatted)"
    if let target, target > 0 {
      text += " of \(HoursValue(minutes: target).formatted)"
    }
    return text
  }
}
