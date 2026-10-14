import Foundation

package enum DayStatus: Equatable, Sendable {
  case notStarted
  case working(since: ClockTime)
  case stopped(lastDeparture: ClockTime)
}

/// The week as fetched, with what is needed to write to it.
package struct WeekSnapshot: Equatable, Sendable {
  package let timesheet: WeekTimesheet
  package let personID: Int
  /// Today as `yyyy-MM-dd`.
  package let todayKey: String

  package var today: WeekDay? {
    timesheet.days.first { $0.key == todayKey }
  }

  package var status: DayStatus {
    guard let today else {
      return .notStarted
    }
    if let since = today.openPeriod?.arrival.clockTime {
      return .working(since: since)
    }
    if let last = today.periods.compactMap(\.departure.clockTime).max() {
      return .stopped(lastDeparture: last)
    }
    return .notStarted
  }

  package func todayWorkedMinutes(now: ClockTime) -> Int {
    today?.workedMinutes(now: now) ?? 0
  }

  /// Today's open period counts up to `now`.
  package func weekWorkedMinutes(now: ClockTime) -> Int {
    timesheet.days.reduce(0) { total, day in
      total + day.workedMinutes(now: day.key == todayKey ? now : nil)
    }
  }

  package var todayTargetMinutes: Int? {
    today?.toDo?.minutes
  }

  package var weekTargetMinutes: Int? {
    timesheet.toDo?.minutes
  }
}
