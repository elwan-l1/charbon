import Foundation

/// Hours wanted on one project on one day.
package struct HoursEdit: Equatable, Sendable {
  package var project: ProjectChoice
  package var minutes: Int

  package init(project: ProjectChoice, minutes: Int) {
    self.project = project
    self.minutes = minutes
  }
}

/// What the user changed on one day.
package struct DayEdit: Equatable, Sendable {
  /// Like `2026-10-12`.
  package var dayKey: String
  /// Every period of the day, as the user wants it.
  package var periods: [PeriodEdit]
  /// The projects whose hours the user touched.
  package var hours: [HoursEdit]

  package init(dayKey: String, periods: [PeriodEdit], hours: [HoursEdit]) {
    self.dayKey = dayKey
    self.periods = periods
    self.hours = hours
  }
}

/// Reads the week and clocks in and out.
///
/// Each write starts from a fresh week, so the row versions it sends are current.
package struct TimesheetService: Sendable {
  private let client: TimesheetClient
  private let calendar: Calendar
  private let noAge: @Sendable () async -> String?

  /// `noAge` gives the value of the web app's `NoAGE` cookie, which the server wants on week
  /// requests.
  package init(
    client: TimesheetClient,
    calendar: Calendar = .current,
    noAge: @escaping @Sendable () async -> String? = { nil }
  ) {
    self.client = client
    self.calendar = calendar
    self.noAge = noAge
  }

  package func snapshot(now: Date) async throws -> WeekSnapshot {
    try await week(containing: now, now: now)
  }

  /// The week that holds `date`.
  package func week(containing date: Date, now: Date) async throws -> WeekSnapshot {
    let sheet = try await client.week(
      containing: Self.dayKey(date, calendar: calendar), noAge: await noAge())
    return try makeSnapshot(sheet, now: now)
  }

  /// The month that holds `date`.
  ///
  /// It has the shape of a week, with all the days of the month.
  package func month(containing date: Date, now: Date) async throws -> WeekSnapshot {
    let sheet = try await client.month(
      containing: Self.dayKey(date, calendar: calendar), noAge: await noAge())
    return try makeSnapshot(sheet, now: now)
  }

  private func makeSnapshot(_ sheet: WeekTimesheet, now: Date) throws -> WeekSnapshot {
    guard let personID = sheet.personID else {
      throw CharbonError.invalidResponse("the timesheet does not say whose it is")
    }
    return WeekSnapshot(
      timesheet: sheet, personID: personID, todayKey: Self.dayKey(now, calendar: calendar))
  }

  package func clockIn(now: Date) async throws -> WeekSnapshot {
    let current = try await snapshot(now: now)
    guard let today = current.today else {
      throw CharbonError.todayUnavailable
    }
    let period = try StampPlanner.clockIn(
      day: today,
      personID: current.personID,
      now: ClockTime(date: now, calendar: calendar)
    )
    _ = try await client.updatePeriod(period)
    return try await snapshot(now: now)
  }

  package func clockOut(now: Date) async throws -> WeekSnapshot {
    let current = try await snapshot(now: now)
    guard let today = current.today else {
      throw CharbonError.todayUnavailable
    }
    let period = try StampPlanner.clockOut(
      day: today,
      now: ClockTime(date: now, calendar: calendar)
    )
    _ = try await client.updatePeriod(period)
    return try await snapshot(now: now)
  }

  package func projects() async throws -> [ProjectChoice] {
    ProjectChoice.choices(from: try await client.projects())
  }

  // Books today's worked time on `project`. An open period counts up to `now`.
  package func bookHours(now: Date, project: ProjectChoice) async throws -> WeekSnapshot {
    let current = try await snapshot(now: now)
    guard let today = current.today else {
      throw CharbonError.todayUnavailable
    }
    guard
      let booking = HoursPlanner.plan(
        day: today,
        personID: current.personID,
        weekProjects: current.timesheet.projects,
        project: project,
        workedMinutes: today.workedMinutes(now: ClockTime(date: now, calendar: calendar))
      )
    else {
      return current
    }
    if booking.needsRow {
      try await client.addRow(
        personID: current.personID,
        projectID: project.projectId,
        activityID: project.activityId
      )
    }
    _ = try await client.updateHours(booking.entry, modifierID: current.personID)
    return try await snapshot(now: now)
  }

  /// Saves the periods and hours the user changed on a day, starting from a fresh week.
  package func save(_ edit: DayEdit) async throws {
    let sheet = try await client.week(containing: edit.dayKey, noAge: await noAge())
    guard let personID = sheet.personID,
      let day = sheet.days.first(where: { $0.key == edit.dayKey })
    else {
      throw CharbonError.todayUnavailable
    }
    let periods = try DayEditPlanner.plan(day: day, personID: personID, edits: edit.periods)
    let bookings = edit.hours.compactMap {
      HoursPlanner.set(
        day: day,
        personID: personID,
        weekProjects: sheet.projects,
        project: $0.project,
        minutes: $0.minutes
      )
    }
    for period in periods {
      _ = try await client.updatePeriod(period)
    }
    try await write(bookings, personID: personID)
  }

  /// Books the time worked on `project` for each of the given days that is not booked yet.
  ///
  /// Returns how many days it booked.
  package func bookDays(_ keys: Set<String>, project: ProjectChoice, now: Date) async throws -> Int
  {
    let todayKey = Self.dayKey(now, calendar: calendar)
    let now = ClockTime(date: now, calendar: calendar)
    let starts = Set(
      keys.compactMap(CharbonCalendar.date(fromKey:)).map(CharbonCalendar.weekStart(of:)))
    var booked = 0
    for start in starts.sorted() {
      let sheet = try await client.week(
        containing: CharbonCalendar.dayKey(start), noAge: await noAge())
      guard let personID = sheet.personID else {
        continue
      }
      let bookings = sheet.days.filter { keys.contains($0.key) && $0.stage == 1 }.compactMap {
        day -> HoursBooking? in
        // a day with an open period that is over has no honest total to book
        if day.key != todayKey, day.openPeriod != nil {
          return nil
        }
        return HoursPlanner.plan(
          day: day,
          personID: personID,
          weekProjects: sheet.projects,
          project: project,
          workedMinutes: day.workedMinutes(now: day.key == todayKey ? now : nil)
        )
      }
      try await write(bookings, personID: personID)
      booked += bookings.count
    }
    return booked
  }

  private func write(_ bookings: [HoursBooking], personID: Int) async throws {
    var addedRows: Set<String> = []
    for booking in bookings {
      let entry = booking.entry
      let id = "\(entry.projectId)/\(entry.activityId)"
      if booking.needsRow, addedRows.insert(id).inserted {
        try await client.addRow(
          personID: personID, projectID: entry.projectId, activityID: entry.activityId)
      }
      _ = try await client.updateHours(entry, modifierID: personID)
    }
  }

  package static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
