import Foundation

package enum DayKind: Equatable, Sendable {
  case work
  case weekend
  case holiday
  /// A day the contract does not ask for, like the eve of a holiday.
  case dayOff
}

/// Something about a past day that the user should fix.
package enum DayIssue: Equatable, Sendable {
  /// An arrival without a departure on a day that is over.
  case missingClockOut(since: ClockTime)
  /// A working day that is over and has no stamp.
  case noStamps
  /// Worked time that is not booked on a project yet.
  case notBooked(minutes: Int)

  /// The issues that stop the day from counting right, unlike a booking that is only late.
  package var isBlocking: Bool {
    switch self {
    case .missingClockOut, .noStamps: true
    case .notBooked: false
    }
  }
}

/// Hours booked on one project on one day.
package struct DayBooking: Equatable, Identifiable, Sendable {
  package let projectId: Int
  package let activityId: Int
  package let minutes: Int

  package var id: String {
    "\(projectId)/\(activityId)"
  }
}

/// What one day holds, worked out for display.
package struct DayReport: Equatable, Identifiable, Sendable {
  package let day: WeekDay
  package let isToday: Bool
  package let isFuture: Bool
  /// Minutes between stamps.
  ///
  /// An open period counts up to now on today only.
  package let worked: Int
  /// Vacation and absences.
  package let credited: Int
  /// What the day asks for, with the hours per day of the settings when they apply.
  package let target: Int
  /// What the contract asks for.
  package let contractTarget: Int
  package let booked: Int
  package let bookings: [DayBooking]
  package let isWorking: Bool
  package let issue: DayIssue?

  package var id: String {
    day.key
  }

  package var kind: DayKind {
    if day.isHoliday {
      return .holiday
    }
    if day.isWeekend {
      return .weekend
    }
    return day.isDayOff ? .dayOff : .work
  }

  /// Whether the day is one to work on.
  package var isWorkday: Bool {
    kind == .work && contractTarget > 0
  }

  package var date: Date? {
    CharbonCalendar.date(fromKey: day.key)
  }

  /// Worked time and credited absences.
  package var done: Int {
    worked + credited
  }

  /// Whether the server refuses changes to the day.
  package var isLocked: Bool {
    day.stage != 1
  }

  package init(
    day: WeekDay,
    todayKey: String,
    now: ClockTime,
    dailyMinutes: Int? = nil
  ) {
    self.day = day
    isToday = day.key == todayKey
    isFuture = day.key > todayKey
    worked = day.workedMinutes(now: day.key == todayKey ? now : nil)
    credited = day.creditedMinutes
    contractTarget = day.toDo?.minutes ?? 0
    if let dailyMinutes, dailyMinutes > 0, contractTarget > 0 {
      target = dailyMinutes
    } else {
      target = contractTarget
    }
    booked = day.bookedMinutes
    bookings = day.projects.compactMap { entry in
      guard let minutes = entry.duration?.minutes, minutes > 0 else {
        return nil
      }
      return DayBooking(projectId: entry.projectId, activityId: entry.activityId, minutes: minutes)
    }
    isWorking = day.key == todayKey && day.openPeriod != nil
    issue = Self.issue(
      day: day,
      todayKey: todayKey,
      worked: worked,
      credited: credited,
      contractTarget: contractTarget
    )
  }

  private static func issue(
    day: WeekDay,
    todayKey: String,
    worked: Int,
    credited: Int,
    contractTarget: Int
  ) -> DayIssue? {
    let isToday = day.key == todayKey
    guard day.key <= todayKey else {
      return nil
    }
    if !isToday, let since = day.openPeriod?.arrival.clockTime {
      return .missingClockOut(since: since)
    }
    let isWorkday = !day.isHoliday && !day.isWeekend && !day.isDayOff && contractTarget > 0
    if !isToday, isWorkday, worked == 0, credited == 0, day.filledPeriods.isEmpty {
      return .noStamps
    }
    let notBooked = worked - day.bookedMinutes
    if !isToday, notBooked > 0 {
      return .notBooked(minutes: notBooked)
    }
    return nil
  }
}
