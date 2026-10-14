import Foundation

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
    let todayKey = Self.dayKey(now, calendar: calendar)
    let week = try await client.week(containing: todayKey, noAge: await noAge())
    guard let personID = week.personID else {
      throw CharbonError.invalidResponse("the timesheet does not say whose it is")
    }
    return WeekSnapshot(timesheet: week, personID: personID, todayKey: todayKey)
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

  package static func dayKey(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
