import CharbonCore
import Foundation

/// Keeps the current week and clocks in and out, one write at a time.
@MainActor
final class TimesheetController {
  private static let staleAfter: TimeInterval = 15
  private static let recoveryInterval: TimeInterval = 60

  private let session: SessionController
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

  init(session: SessionController) {
    self.session = session
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
    await perform { try await $0.clockIn(now: Date()) }
  }

  func clockOut() async {
    await perform { try await $0.clockOut(now: Date()) }
  }

  private func perform(_ operation: (TimesheetService) async throws -> WeekSnapshot) async {
    guard !isBusy else {
      return
    }
    isBusy = true
    message = nil
    onChange?()
    if await !run(operation), let fresh = try? await service.snapshot(now: Date()) {
      // the write failed, so show what the server really holds
      snapshot = fresh
      lastRefresh = Date()
    }
    isBusy = false
    onChange?()
  }

  // Returns whether the operation worked. The week is stale when someone else changed it
  // since it was read, and every attempt reads it again, so one more attempt is enough.
  private func run(_ operation: (TimesheetService) async throws -> WeekSnapshot) async -> Bool {
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
