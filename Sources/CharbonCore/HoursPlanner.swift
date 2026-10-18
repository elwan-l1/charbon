import Foundation

/// Hours to save on the default project.
package struct HoursBooking: Equatable, Sendable {
  package let entry: ProjectHours
  /// Whether the project must be added to the week first.
  package let needsRow: Bool
  package let hours: HoursValue
}

/// Works out how many hours to book on a project.
package enum HoursPlanner {
  /// Hours already booked on other projects the same day are kept, so only the rest lands on the
  /// default project. `nil` when nothing changes.
  package static func plan(
    day: WeekDay,
    personID: Int,
    weekProjects: [WeekProject],
    project: ProjectChoice,
    workedMinutes: Int
  ) -> HoursBooking? {
    let bookedElsewhere =
      day.projects
      .filter { !project.matches($0) }
      .reduce(0) { $0 + ($1.duration?.minutes ?? 0) }
    let target = workedMinutes - bookedElsewhere
    guard target > 0 else {
      return nil
    }
    return set(
      day: day,
      personID: personID,
      weekProjects: weekProjects,
      project: project,
      minutes: target
    )
  }

  /// Books exactly `minutes` on `project`, or clears the booking for 0. `nil` when nothing changes.
  package static func set(
    day: WeekDay,
    personID: Int,
    weekProjects: [WeekProject],
    project: ProjectChoice,
    minutes: Int
  ) -> HoursBooking? {
    let existing = day.projects.first { project.matches($0) }
    guard minutes != (existing?.duration?.minutes ?? 0) else {
      return nil
    }
    let hours = HoursValue(minutes: minutes)
    var entry =
      existing
      ?? ProjectHours(
        day: day.date,
        personId: personID,
        activityId: project.activityId,
        projectId: project.projectId,
        hours: "",
        stage: day.stage
      )
    entry.hours = minutes > 0 ? hours.formatted : ""
    return HoursBooking(
      entry: entry,
      needsRow: minutes > 0 && !weekProjects.contains { project.matches($0) },
      hours: hours
    )
  }
}
