import Foundation

/// A project activity shown as a row of the week.
package struct WeekProject: Decodable, Equatable, Sendable {
  package let projectId: Int
  package let activityId: Int
  /// Like `139665 - Demo`.
  package let projectTitle: String
  /// Like `Demo`, without the number.
  package let projectName: String
  package let activityTitle: String
  package let personId: Int

  private enum CodingKeys: String, CodingKey {
    case projectId = "ProjectId"
    case activityId = "ActivityId"
    case projectTitle = "ProjectTitle"
    case projectName = "ProjectFullTitle"
    case activityTitle = "ActivityTitle"
    case personId = "PersonId"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    projectId = container.lossy(.projectId, default: 0)
    activityId = container.lossy(.activityId, default: 0)
    projectTitle = container.lossy(.projectTitle, default: "")
    projectName = container.lossy(.projectName, default: "")
    activityTitle = container.lossy(.activityTitle, default: "")
    personId = container.lossy(.personId, default: 0)
  }
}

package struct WeekDay: Decodable, Equatable, Sendable {
  /// Like `2026-10-12T00:00:00`.
  package let date: String
  package let isWeekend: Bool
  package let isHoliday: Bool
  /// A day the contract does not ask for, like the eve of a holiday.
  package let isDayOff: Bool
  package let dayOffName: String?
  /// `1` means editable.
  package let stage: Int
  /// The hours the contract asks for on this day.
  package let toDo: HoursValue?
  package let periods: [PeriodTime]
  package let projects: [ProjectHours]
  /// Vacation booked on this day.
  package let vacation: ProjectHours?
  /// Other absences booked on this day.
  package let absences: [ProjectHours]

  private enum CodingKeys: String, CodingKey {
    case date = "Date"
    case isWeekend = "IsWeekend"
    case isHoliday = "IsHoliday"
    case isDayOff = "IsDayOff"
    case dayOffName = "DayOffName"
    case stage = "Stage"
    case total = "Total"
    case periods = "PeriodTimes"
    case projects = "Projects"
    case vacation = "Vacancy"
    case absences = "Absences"
  }

  private enum TotalKeys: String, CodingKey {
    case toDo = "ToDo"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = container.lossy(.date, default: "")
    isWeekend = container.lossy(.isWeekend, default: false)
    isHoliday = container.lossy(.isHoliday, default: false)
    isDayOff = container.lossy(.isDayOff, default: false)
    dayOffName = try? container.decodeIfPresent(String.self, forKey: .dayOffName)
    stage = container.lossy(.stage, default: 1)
    if let total = try? container.nestedContainer(keyedBy: TotalKeys.self, forKey: .total) {
      toDo = HoursValue(total.lossy(.toDo, default: ""))
    } else {
      toDo = nil
    }
    periods = container.lossy(.periods, default: [PeriodTime]())
    projects = container.lossy(.projects, default: [ProjectHours]())
    vacation = try? container.decodeIfPresent(ProjectHours.self, forKey: .vacation)
    absences = container.lossy(.absences, default: [ProjectHours]())
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

  /// Vacation and absences, which count as time done.
  package var creditedMinutes: Int {
    ((vacation.map { [$0] } ?? []) + absences).reduce(0) { $0 + ($1.duration?.minutes ?? 0) }
  }

  package var bookedMinutes: Int {
    projects.reduce(0) { $0 + ($1.duration?.minutes ?? 0) }
  }

  /// The periods with something in them, in order.
  package var filledPeriods: [PeriodTime] {
    periods.filter { !$0.isEmpty }.sorted { $0.displayOrder < $1.displayOrder }
  }
}

/// The answer of `TimeSheet/Week`, or of `TimeSheet/Month`, which has the same shape.
package struct WeekTimesheet: Decodable, Equatable, Sendable {
  /// The first day of the week, or of the month.
  package let mondayDate: String
  package let sundayDate: String
  /// The hours the contract asks for over the whole span.
  package let toDo: HoursValue?
  /// The overtime balance before the first day.
  package let startBalance: HoursValue?
  /// Vacation left this year.
  package let vacationBalance: HoursValue?
  /// `1` means editable.
  package let stage: Int
  package let projects: [WeekProject]
  package let days: [WeekDay]

  private enum CodingKeys: String, CodingKey {
    case mondayDate = "MondayDate"
    case sundayDate = "SundayDate"
    case total = "Total"
    case vacancy = "Vacancy"
    case stage = "Stage"
    case projects = "Projects"
    case days = "Days"
  }

  private enum TotalKeys: String, CodingKey {
    case toDo = "ToDo"
    case balance = "Balance"
  }

  private enum VacancyKeys: String, CodingKey {
    case balance = "Balance"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mondayDate = container.lossy(.mondayDate, default: "")
    sundayDate = container.lossy(.sundayDate, default: "")
    if let total = try? container.nestedContainer(keyedBy: TotalKeys.self, forKey: .total) {
      toDo = HoursValue(total.lossy(.toDo, default: ""))
      startBalance = HoursValue(total.lossy(.balance, default: ""))
    } else {
      toDo = nil
      startBalance = nil
    }
    // The vacation balance is a number of seconds.
    if let vacancy = try? container.nestedContainer(keyedBy: VacancyKeys.self, forKey: .vacancy),
      let seconds = try? vacancy.decodeIfPresent(Int.self, forKey: .balance)
    {
      vacationBalance = HoursValue(seconds: seconds)
    } else {
      vacationBalance = nil
    }
    stage = container.lossy(.stage, default: 1)
    projects = container.lossy(.projects, default: [WeekProject]())
    days = container.lossy(.days, default: [WeekDay]())
  }

  /// The owner of the timesheet, read from the first record that carries it.
  package var personID: Int? {
    let fromPeriods = days.lazy.flatMap(\.periods).map(\.personId).first { $0 != 0 }
    return fromPeriods ?? projects.map(\.personId).first { $0 != 0 }
  }
}
