import Foundation

/// The text the menu and the menu bar show about today and this week.
package struct StatusSummary: Equatable, Sendable {
  package var headline: String
  package var lines: [String]
  /// Next to the icon. `nil` means only the icon.
  package var barTitle: String?

  package static func make(
    snapshot: WeekSnapshot,
    now: ClockTime,
    settings: CharbonSettings
  ) -> StatusSummary {
    let todayWorked = snapshot.todayWorkedMinutes(now: now)
    let (todayTarget, weekTarget) = targets(
      snapshot: snapshot,
      dailyHours: settings.dailyHoursOverride
    )
    let rate = settings.hourlyRate(contractMinutes: snapshot.weekTargetMinutes)

    var isWorking = false
    let headline: String
    switch snapshot.status {
    case .notStarted:
      headline = "Not clocked in yet"
    case .working(let since):
      headline = "Clocked in since \(since)"
      isWorking = true
    case .stopped(let end):
      headline = "Clocked out at \(end)"
    }
    var lines = [
      line("Today", worked: todayWorked, target: todayTarget, rate: rate),
      line(
        "This week",
        worked: snapshot.weekWorkedMinutes(now: now),
        target: weekTarget,
        rate: rate
      ),
    ]
    let booked = snapshot.todayBookedMinutes
    if booked > 0 {
      lines.append("Booked: \(HoursValue(minutes: booked).formatted)")
    }
    return StatusSummary(
      headline: headline,
      lines: lines,
      barTitle: settings.menuBarDisplay.text(
        workedMinutes: todayWorked,
        targetMinutes: todayTarget,
        hourlyRate: rate,
        isWorking: isWorking
      )
    )
  }

  // `dailyHours` replaces the hours of the contract on every day that has some.
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

  private static func line(_ title: String, worked: Int, target: Int?, rate: Double?) -> String {
    var text = "\(title): \(HoursValue(minutes: worked).formatted)"
    if let target, target > 0 {
      text += " of \(HoursValue(minutes: target).formatted)"
    }
    if let rate {
      text += " · " + RateCalculator.format(RateCalculator.earnings(minutes: worked, rate: rate))
    }
    return text
  }
}
