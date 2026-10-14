import Foundation

/// Hours to save on the default project.
package struct HoursBooking: Equatable, Sendable {
  package let entry: ProjectHours
  /// Whether the project must be added to the week first.
  package let needsRow: Bool
  package let hours: HoursValue
}

/// Works out how many hours to book on the default project.
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
    let existing = day.projects.first { project.matches($0) }
    if existing?.duration?.minutes == target {
      return nil
    }
    let hours = HoursValue(minutes: target)
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
    entry.hours = hours.formatted
    return HoursBooking(
      entry: entry,
      needsRow: !weekProjects.contains { project.matches($0) },
      hours: hours
    )
  }
}
