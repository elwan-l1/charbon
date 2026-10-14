import CharbonCore
import Foundation

/// Keeps the current week and clocks in and out, one write at a time.
@MainActor
final class TimesheetController {
  private static let staleAfter: TimeInterval = 15
  private static let recoveryInterval: TimeInterval = 60

  private typealias Operation = (TimesheetService) async throws -> WeekSnapshot

  private let session: SessionController
  private let settings: SettingsModel
  private let service = TimesheetService(
    client: TimesheetClient(transport: WebKitTransport()),
    noAge: { await WebKitTransport.cookieValue(named: "NoAGE") }
  )

  private var lastRefresh = Date.distantPast
  private var lastRecovery = Date.distantPast

  private(set) var snapshot: WeekSnapshot?
  private(set) var message: String?
  private(set) var isBusy = false

  var onChange: (() -> Void)?

  init(session: SessionController, settings: SettingsModel) {
    self.session = session
    self.settings = settings
  }

  func sessionChanged(to state: SessionController.State) {
    switch state {
    case .signedIn:
      Task { await refresh() }
    case .loginRequired:
      snapshot = nil
      message = nil
      onChange?()
    case .unknown, .checking, .failed:
      break
    }
  }

  func refreshIfStale() {
    guard case .signedIn = session.state, Date().timeIntervalSince(lastRefresh) > Self.staleAfter
    else {
      return
    }
    Task { await refresh() }
  }

  func refresh() async {
    guard !isBusy else {
      return
    }
    _ = await run { try await $0.snapshot(now: Date()) }
  }

  func clockIn() async {
    await perform([{ try await $0.clockIn(now: Date()) }])
  }

  // The stamp is saved first. If booking fails after it, the stamp stays.
  func clockOut() async {
    var steps: [Operation] = [{ try await $0.clockOut(now: Date()) }]
    if let project = settings.settings.defaultProject {
      steps.append { try await $0.bookHours(now: Date(), project: project) }
    }
    await perform(steps)
  }

  func projectChoices() async throws -> [ProjectChoice] {
    try await service.projects()
      .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
  }

  // Runs the steps one after the other and stops at the first failure.
  private func perform(_ steps: [Operation]) async {
    guard !isBusy else {
      return
    }
    isBusy = true
    message = nil
    onChange?()
    for step in steps {
      guard await run(step) else {
        if let fresh = try? await service.snapshot(now: Date()) {
          // a step failed, so show what the server really holds
          snapshot = fresh
          lastRefresh = Date()
        }
        break
      }
    }
    isBusy = false
    onChange?()
  }

  // Returns whether the operation worked. The week is stale when someone else changed it
  // since it was read, and every attempt reads it again, so one more attempt is enough.
  private func run(_ operation: Operation) async -> Bool {
    defer { onChange?() }
    do {
      do {
        snapshot = try await operation(service)
      } catch CharbonError.staleData {
        snapshot = try await operation(service)
      }
      lastRefresh = Date()
      message = nil
      return true
    } catch {
      message = error.localizedDescription
      if let error = error as? CharbonError, error == .sessionExpired || error == .notSignedIn {
        await recover()
      }
      return false
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
}
