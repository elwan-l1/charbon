import CharbonCore
import Foundation
import Observation

/// A stretch of days the app can show.
enum Span {
  case week
  case month
}

/// Keeps the weeks and months it has read, and clocks in and out, one write at a time.
@MainActor
@Observable
final class TimesheetController {
  private static let staleAfter: TimeInterval = 15
  private static let recoveryInterval: TimeInterval = 60

  // A write. It gives back the week of today when it has read it, or `nil`.
  private typealias Step = (TimesheetService) async throws -> WeekSnapshot?

  private let session: SessionController
  private let settings: SettingsModel
  @ObservationIgnored private let service = TimesheetService(
    client: TimesheetClient(transport: WebKitTransport()),
    noAge: { await WebKitTransport.cookieValue(named: "NoAGE") }
  )

  @ObservationIgnored private var fetchedAt: [String: Date] = [:]
  @ObservationIgnored private var inFlight: Set<String> = []
  @ObservationIgnored private var lastRecovery = Date.distantPast

  var weeks: [String: WeekSnapshot] = [:]
  var months: [String: WeekSnapshot] = [:]
  private(set) var message: String?
  private(set) var isBusy = false
  /// Reads that are running, so the window can show it is working.
  private(set) var loads = 0

  @ObservationIgnored var onChange: (() -> Void)?

  init(session: SessionController, settings: SettingsModel) {
    self.session = session
    self.settings = settings
  }

  /// The week of today, which the menu bar shows.
  var snapshot: WeekSnapshot? {
    weeks[Self.key(.week, Date())]
  }

  /// What has been read for the week or month that holds `date`.
  func snapshot(_ span: Span, containing date: Date) -> WeekSnapshot? {
    switch span {
    case .week: weeks[Self.key(.week, date)]
    case .month: months[Self.key(.month, date)]
    }
  }

  func sessionChanged(to state: SessionController.State) {
    switch state {
    case .signedIn:
      Task { await refresh() }
    case .loginRequired:
      weeks = [:]
      months = [:]
      fetchedAt = [:]
      message = nil
      onChange?()
    case .unknown, .checking, .failed:
      break
    }
  }

  func refreshIfStale() {
    guard case .signedIn = session.state else {
      return
    }
    let key = Self.key(.week, Date())
    guard Date().timeIntervalSince(fetchedAt["w" + key] ?? .distantPast) > Self.staleAfter else {
      return
    }
    Task { await refresh() }
  }

  /// Reads the week and the month of today, again unless `force` is off and they are fresh.
  func refresh(force: Bool = true) async {
    guard !isBusy else {
      return
    }
    let now = Date()
    async let week: Void = load(.week, containing: now, force: force)
    async let month: Void = load(.month, containing: now, force: force)
    _ = await (week, month)
  }

  /// Reads the week or month that holds `date` unless it is fresh, then the ones next to it.
  func show(_ span: Span, containing date: Date, force: Bool = false) async {
    await load(span, containing: date, force: force)
    let step = span == .week ? 7 : 1
    let neighbors = [-step, step].map {
      span == .week
        ? CharbonCalendar.addingDays($0, to: date) : CharbonCalendar.addingMonths($0, to: date)
    }
    for neighbor in neighbors {
      await load(span, containing: neighbor, force: false)
    }
  }

  func load(_ span: Span, containing date: Date, force: Bool) async {
    guard case .signedIn = session.state else {
      return
    }
    let key = Self.key(span, date)
    let stamp = (span == .week ? "w" : "m") + key
    if !force, Date().timeIntervalSince(fetchedAt[stamp] ?? .distantPast) < Self.staleAfter {
      return
    }
    guard inFlight.insert(stamp).inserted else {
      return
    }
    loads += 1
    defer {
      inFlight.remove(stamp)
      loads -= 1
    }
    do {
      let now = Date()
      switch span {
      case .week: weeks[key] = try await service.week(containing: date, now: now)
      case .month: months[key] = try await service.month(containing: date, now: now)
      }
      fetchedAt[stamp] = Date()
      if message != nil, !isBusy {
        message = nil
      }
      onChange?()
    } catch {
      await fail(error)
    }
  }

  func clockIn() async {
    await mutate(touching: [Date()], steps: [{ try await $0.clockIn(now: Date()) }])
  }

  // The stamp is saved first. If booking fails after it, the stamp stays.
  func clockOut() async {
    var steps: [Step] = [{ try await $0.clockOut(now: Date()) }]
    if let project = settings.settings.defaultProject {
      steps.append { try await $0.bookHours(now: Date(), project: project) }
    }
    await mutate(touching: [Date()], steps: steps)
  }

  /// Saves what the user changed on a day.
  ///
  /// Returns the reason when it failed.
  func save(_ edit: DayEdit) async -> String? {
    let date = CharbonCalendar.date(fromKey: edit.dayKey) ?? Date()
    return await mutate(
      touching: [date, Date()],
      steps: [
        {
          try await $0.save(edit)
          return nil
        }
      ]
    )
  }

  /// Books the worked time of the given days on the default project.
  ///
  /// Returns the reason when it failed.
  func bookDays(_ days: [DayReport]) async -> String? {
    guard let project = settings.settings.defaultProject else {
      return "Choose a default project in Settings first."
    }
    let keys = Set(days.map(\.id))
    let dates = days.compactMap(\.date)
    return await mutate(
      touching: dates + [Date()],
      steps: [
        {
          _ = try await $0.bookDays(keys, project: project, now: Date())
          return nil
        }
      ]
    )
  }

  func projectChoices() async throws -> [ProjectChoice] {
    try await service.projects()
      .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }

  // Runs the write, then reads again every week and month it may have changed, so the screen
  // shows what the server really holds, also when the write failed halfway.
  @discardableResult
  private func mutate(touching dates: [Date], steps: [Step]) async -> String? {
    guard !isBusy else {
      return "Another change is still being saved."
    }
    isBusy = true
    message = nil
    onChange?()
    var failure: String?
    do {
      for step in steps {
        guard let fresh = try await attempt(step) else {
          continue
        }
        weeks[Self.key(.week, Date())] = fresh
        fetchedAt["w" + Self.key(.week, Date())] = Date()
        onChange?()
      }
    } catch {
      failure = error.localizedDescription
      message = failure
      await recoverIfNeeded(error)
    }
    isBusy = false
    onChange?()
    await reload(dates)
    return failure
  }

  // The week is stale when someone else changed it since it was read, and every attempt reads
  // it again, so one more attempt is enough.
  private func attempt(_ step: Step) async throws -> WeekSnapshot? {
    do {
      return try await step(service)
    } catch CharbonError.staleData {
      return try await step(service)
    }
  }

  private func reload(_ dates: [Date]) async {
    var wanted: [(Span, Date)] = []
    var seen: Set<String> = []
    for date in dates {
      for span in [Span.week, .month] where seen.insert("\(span)" + Self.key(span, date)).inserted {
        wanted.append((span, date))
      }
    }
    await withTaskGroup(of: Void.self) { group in
      for (span, date) in wanted {
        group.addTask { await self.load(span, containing: date, force: true) }
      }
    }
  }

  private func fail(_ error: any Error) async {
    message = error.localizedDescription
    onChange?()
    await recoverIfNeeded(error)
  }

  private func recoverIfNeeded(_ error: any Error) async {
    if let error = error as? CharbonError, error == .sessionExpired || error == .notSignedIn {
      await recover()
    }
  }

  // Renews the session, at most once a minute. The login window opens only when the renewal says
  // a login is needed: a valid session would close it at once and reopen it forever.
  private func recover() async {
    guard Date().timeIntervalSince(lastRecovery) > Self.recoveryInterval else {
      return
    }
    lastRecovery = Date()
    await session.renewNow()
    if session.state == .loginRequired {
      session.showLogin()
    }
  }

  /// The key of the week or month that holds `date`: its first day.
  static func key(_ span: Span, _ date: Date) -> String {
    switch span {
    case .week: CharbonCalendar.dayKey(CharbonCalendar.weekStart(of: date))
    case .month: CharbonCalendar.dayKey(CharbonCalendar.monthStart(of: date))
    }
  }
}
