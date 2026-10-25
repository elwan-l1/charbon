import CharbonCore
import Foundation
import Observation

enum Screen: String, CaseIterable, Identifiable {
  case today
  case week
  case month
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .today: "Today"
    case .week: "Week"
    case .month: "Month"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .today: "clock"
    case .week: "chart.bar"
    case .month: "calendar"
    case .settings: "gearshape"
    }
  }
}

/// The day the editor is open on.
struct EditingDay: Identifiable {
  let id: String
}

/// What the window shows and where it is looking in time.
@MainActor
@Observable
final class AppModel {
  var screen = Screen.today
  /// Any date of the week the week screen shows.
  var weekAnchor = Date()
  /// Any date of the month the month screen shows.
  var monthAnchor = Date()
  var editing: EditingDay?
  var sessionState = SessionController.State.unknown
  // What stops the session, and whether it failed often enough to write to the maintainer.
  var sessionProblem: CharbonProblem?
  var showsSessionContact = false

  let session: SessionController
  let timesheet: TimesheetController
  let settings: SettingsModel

  init(session: SessionController, timesheet: TimesheetController, settings: SettingsModel) {
    self.session = session
    self.timesheet = timesheet
    self.settings = settings
  }

  /// The hours per day of the settings, in minutes, when the user set them.
  var dailyMinutes: Int? {
    settings.settings.dailyHoursOverride.map { Int(($0 * 60).rounded()) }
  }

  /// The pay per hour.
  ///
  /// It comes from the longest week read, as a week with a holiday is shorter.
  var hourlyRate: Double? {
    settings.settings.hourlyRate(contractMinutes: contractWeekMinutes)
  }

  /// The hours of a normal week of the contract, in minutes.
  var contractWeekMinutes: Int? {
    timesheet.weeks.values.compactMap(\.weekTargetMinutes).max()
  }

  func report(for snapshot: WeekSnapshot, now: Date) -> PeriodReport {
    PeriodReport.make(
      sheet: snapshot.timesheet,
      todayKey: CharbonCalendar.dayKey(now),
      now: ClockTime(date: now),
      dailyMinutes: dailyMinutes
    )
  }

  var isOnCurrentPeriod: Bool {
    let now = Date()
    switch screen {
    case .today, .settings:
      return true
    case .week:
      return TimesheetController.key(.week, weekAnchor) == TimesheetController.key(.week, now)
    case .month:
      return TimesheetController.key(.month, monthAnchor) == TimesheetController.key(.month, now)
    }
  }

  /// Moves the week or the month by `delta`.
  func step(_ delta: Int) {
    switch screen {
    case .today, .settings:
      break
    case .week:
      weekAnchor = CharbonCalendar.addingDays(7 * delta, to: weekAnchor)
    case .month:
      monthAnchor = CharbonCalendar.addingMonths(delta, to: monthAnchor)
    }
  }

  func goToCurrent() {
    weekAnchor = Date()
    monthAnchor = Date()
  }

  func edit(_ dayKey: String) {
    editing = EditingDay(id: dayKey)
  }

  func openWeek(containing date: Date) {
    weekAnchor = date
    screen = .week
  }

  func refresh() {
    Task {
      await timesheet.refresh()
      switch screen {
      case .today, .settings: break
      case .week: await timesheet.show(.week, containing: weekAnchor, force: true)
      case .month: await timesheet.show(.month, containing: monthAnchor, force: true)
      }
    }
  }
}
