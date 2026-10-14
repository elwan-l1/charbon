import Foundation

/// A project activity shown as a row of the week.
package struct WeekProject: Decodable, Equatable, Sendable {
  package let projectId: Int
  package let activityId: Int
  package let projectTitle: String
  package let activityTitle: String
  package let personId: Int

  private enum CodingKeys: String, CodingKey {
    case projectId = "ProjectId"
    case activityId = "ActivityId"
    case projectTitle = "ProjectTitle"
    case activityTitle = "ActivityTitle"
    case personId = "PersonId"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    projectId = container.lossy(.projectId, default: 0)
    activityId = container.lossy(.activityId, default: 0)
    projectTitle = container.lossy(.projectTitle, default: "")
    activityTitle = container.lossy(.activityTitle, default: "")
    personId = container.lossy(.personId, default: 0)
  }
}

package struct WeekDay: Decodable, Equatable, Sendable {
  /// Like `2026-10-12T00:00:00`.
  package let date: String
  package let isWeekend: Bool
  package let isHoliday: Bool
  /// `1` means editable.
  package let stage: Int
  /// The hours the contract asks for on this day.
  package let toDo: HoursValue?
  package let periods: [PeriodTime]
  package let projects: [ProjectHours]

  private enum CodingKeys: String, CodingKey {
    case date = "Date"
    case isWeekend = "IsWeekend"
    case isHoliday = "IsHoliday"
    case stage = "Stage"
    case total = "Total"
    case periods = "PeriodTimes"
    case projects = "Projects"
  }

  private enum TotalKeys: String, CodingKey {
    case toDo = "ToDo"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = container.lossy(.date, default: "")
    isWeekend = container.lossy(.isWeekend, default: false)
    isHoliday = container.lossy(.isHoliday, default: false)
    stage = container.lossy(.stage, default: 1)
    if let total = try? container.nestedContainer(keyedBy: TotalKeys.self, forKey: .total) {
      toDo = HoursValue(total.lossy(.toDo, default: ""))
    } else {
      toDo = nil
    }
    periods = container.lossy(.periods, default: [PeriodTime]())
    projects = container.lossy(.projects, default: [ProjectHours]())
  }

  /// The `yyyy-MM-dd` part of `date`.
  package var key: String {
    String(date.prefix(10))
  }

  package var openPeriod: PeriodTime? {
    periods.sorted { $0.displayOrder < $1.displayOrder }.last(where: \.isOpen)
  }

  /// An open period counts up to `now` when it is given.
  package func workedMinutes(now: ClockTime?) -> Int {
    periods.reduce(0) { $0 + $1.workedMinutes(now: now) }
  }
}

/// The answer of `TimeSheet/Week`.
package struct WeekTimesheet: Decodable, Equatable, Sendable {
  package let mondayDate: String
  /// The hours the contract asks for over the week.
  package let toDo: HoursValue?
  package let projects: [WeekProject]
  package let days: [WeekDay]

  private enum CodingKeys: String, CodingKey {
    case mondayDate = "MondayDate"
    case total = "Total"
    case projects = "Projects"
    case days = "Days"
  }

  private enum TotalKeys: String, CodingKey {
    case toDo = "ToDo"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mondayDate = container.lossy(.mondayDate, default: "")
    if let total = try? container.nestedContainer(keyedBy: TotalKeys.self, forKey: .total) {
      toDo = HoursValue(total.lossy(.toDo, default: ""))
    } else {
      toDo = nil
    }
    projects = container.lossy(.projects, default: [WeekProject]())
    days = container.lossy(.days, default: [WeekDay]())
  }

  /// The owner of the timesheet, read from the first record that carries it.
  package var personID: Int? {
    let fromPeriods = days.lazy.flatMap(\.periods).map(\.personId).first { $0 != 0 }
    return fromPeriods ?? projects.map(\.personId).first { $0 != 0 }
  }
}
