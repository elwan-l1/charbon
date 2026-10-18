import Foundation

/// The share of the worked time that one project got.
package struct ProjectShare: Equatable, Identifiable, Sendable {
  package let projectId: Int
  package let activityId: Int
  /// Like `139665 - Demo`.
  package let title: String
  /// Like `Demo`.
  package let name: String
  package let minutes: Int
  /// Between 0 and 1, of the time worked or booked, whichever is larger.
  package let fraction: Double

  package var id: String {
    "\(projectId)/\(activityId)"
  }
}

/// Worked and expected time of one week of a month.
package struct WeekTotal: Equatable, Identifiable, Sendable {
  /// The Monday of the week, as `yyyy-MM-dd`.
  package let id: String
  package let number: Int
  package let worked: Int
  package let target: Int
}

/// The days of a week or of a month with what they add up to.
package struct PeriodReport: Equatable, Sendable {
  package let days: [DayReport]
  package let worked: Int
  /// Vacation and absences.
  package let credited: Int
  package let target: Int
  /// What the days up to today ask for.
  package let targetSoFar: Int
  package let booked: Int
  package let shares: [ProjectShare]
  /// Worked time that is not booked on any project.
  package let unbookedMinutes: Int
  package let unbookedFraction: Double
  /// The overtime balance before the first day.
  package let startBalance: Int?
  /// The overtime balance after the days that are over.
  package let balance: Int?
  package let workedDays: Int
  package let weekTotals: [WeekTotal]
  package let vacationBalance: Int?

  /// The days with something to fix, most recent last.
  package var issues: [DayReport] {
    days.filter { $0.issue != nil }
  }

  /// Days with a booking to make, which the user can book in one go.
  package var unbookedDays: [DayReport] {
    days.filter {
      guard case .notBooked? = $0.issue else {
        return false
      }
      return !$0.isLocked
    }
  }

  /// Minutes per working day, over the days that have some.
  package var averagePerWorkedDay: Int {
    workedDays > 0 ? worked / workedDays : 0
  }

  /// Time worked or credited, minus what the days so far asked for.
  package var difference: Int {
    worked + credited - targetSoFar
  }

  package static func make(
    sheet: WeekTimesheet,
    todayKey: String,
    now: ClockTime,
    dailyMinutes: Int? = nil
  ) -> PeriodReport {
    let days = sheet.days.map {
      DayReport(day: $0, todayKey: todayKey, now: now, dailyMinutes: dailyMinutes)
    }
    let worked = days.reduce(0) { $0 + $1.worked }
    let booked = days.reduce(0) { $0 + $1.booked }
    let (shares, unbooked) = Self.shares(days: days, sheet: sheet, worked: worked, booked: booked)
    let denominator = Double(max(worked, booked))
    let balance = sheet.startBalance.map { start in
      start.minutes + Self.settledDifference(days)
    }
    return PeriodReport(
      days: days,
      worked: worked,
      credited: days.reduce(0) { $0 + $1.credited },
      target: days.reduce(0) { $0 + $1.target },
      targetSoFar: days.filter { !$0.isFuture }.reduce(0) { $0 + $1.target },
      booked: booked,
      shares: shares,
      unbookedMinutes: unbooked,
      unbookedFraction: denominator > 0 ? Double(unbooked) / denominator : 0,
      startBalance: sheet.startBalance?.minutes,
      balance: balance,
      workedDays: days.filter { $0.worked > 0 }.count,
      weekTotals: Self.weekTotals(days),
      vacationBalance: sheet.vacationBalance?.minutes
    )
  }

  // Days that are over count in full. Today counts once the user has stopped for the day.
  private static func settledDifference(_ days: [DayReport]) -> Int {
    days.filter { day in
      if day.isFuture {
        return false
      }
      if day.isToday {
        return !day.isWorking && (day.worked > 0 || day.contractTarget == 0)
      }
      return true
    }
    .reduce(0) { $0 + $1.done - $1.contractTarget }
  }

  private static func shares(
    days: [DayReport],
    sheet: WeekTimesheet,
    worked: Int,
    booked: Int
  ) -> ([ProjectShare], Int) {
    var minutes: [String: Int] = [:]
    for booking in days.lazy.flatMap(\.bookings) {
      minutes[booking.id, default: 0] += booking.minutes
    }
    let denominator = Double(max(worked, booked))
    let shares = minutes.map { id, total in
      let ids = id.split(separator: "/").compactMap { Int($0) }
      let row = sheet.projects.first { "\($0.projectId)/\($0.activityId)" == id }
      return ProjectShare(
        projectId: ids.first ?? 0,
        activityId: ids.last ?? 0,
        title: row?.projectTitle ?? "Project \(ids.first ?? 0)",
        name: row?.projectName ?? "Project \(ids.first ?? 0)",
        minutes: total,
        fraction: denominator > 0 ? Double(total) / denominator : 0
      )
    }
    .sorted { ($1.minutes, $0.title) < ($0.minutes, $1.title) }
    return (shares, max(worked - booked, 0))
  }

  private static func weekTotals(_ days: [DayReport]) -> [WeekTotal] {
    var order: [String] = []
    var groups: [String: [DayReport]] = [:]
    for day in days {
      guard let date = day.date else {
        continue
      }
      let key = CharbonCalendar.dayKey(CharbonCalendar.weekStart(of: date))
      if groups[key] == nil {
        order.append(key)
      }
      groups[key, default: []].append(day)
    }
    return order.compactMap { key in
      guard let members = groups[key], let start = CharbonCalendar.date(fromKey: key) else {
        return nil
      }
      return WeekTotal(
        id: key,
        number: CharbonCalendar.weekNumber(of: start),
        worked: members.reduce(0) { $0 + $1.worked },
        target: members.reduce(0) { $0 + $1.target }
      )
    }
  }
}
