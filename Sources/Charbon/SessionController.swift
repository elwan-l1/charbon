import AppKit
import CharbonCore
import OSLog
import WebKit

@MainActor
final class SessionController {
  enum State: Equatable {
    case unknown
    case checking
    case signedIn(minutesRemaining: Int)
    case loginRequired
    case failed
  }

  /// Failed renewals in a row before the user is told they can write to the maintainer.
  static let contactAfterFailures = 3

  // The network is often not back yet when the Mac wakes up.
  static let retryInterval: Duration = .seconds(15)

  // A renewal logs in again with the saved login when the identity provider forgot the user, so
  // the timer only has to be regular. The jitter keeps it from a perfectly regular rhythm.
  private static let renewalMinutes = 90
  private static let jitterMinutes = 20

  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "session")

  private(set) var state = State.unknown {
    didSet { onChange?(state) }
  }

  // What went wrong last, until a renewal works. Set before `state` changes.
  private(set) var problem: CharbonProblem?
  // Renewals that failed in a row.
  private(set) var failures = 0

  var onChange: ((State) -> Void)?

  private let renewer = SessionRenewer()
  private var loginWindow: LoginWindowController?
  private var nextRenewal: Task<Void, Never>?
  private var isRenewing = false
  private var wakeObserver: (any NSObjectProtocol)?

  func start() {
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.renewNow() }
    }
    Task {
      await CookieVault.restore()
      await renewNow()
    }
  }

  func renewNow() async {
    guard !isRenewing else {
      return
    }
    isRenewing = true
    defer { isRenewing = false }
    nextRenewal?.cancel()
    state = .checking
    do {
      let minutes = try await renewer.renew()
      Self.logger.notice("Session renewed, \(minutes) minutes left")
      await signIn(minutes: minutes)
    } catch CharbonError.sessionExpired {
      Self.logger.notice("Session cannot be renewed, a login is required")
      problem = nil
      failures = 0
      state = .loginRequired
    } catch {
      record(error)
      if case CharbonError.autoLoginFailed = error {
        state = .loginRequired
      } else {
        state = .failed
        schedule(after: Self.retryInterval)
      }
    }
  }

  var showsContact: Bool {
    problem != nil && failures >= Self.contactAfterFailures
  }

  // Logs in with the saved login in a web view that remembers nothing, so the identity provider
  // has to ask for it. The real session is left as it is.
  func testSavedLogin() async -> Bool {
    let renewer = SessionRenewer(dataStore: .nonPersistent())
    return (try? await renewer.renew()) != nil
  }

  func showLogin() {
    let controller =
      loginWindow
      ?? LoginWindowController { [weak self] minutes in
        guard let self else {
          return
        }
        Task { await self.signIn(minutes: minutes) }
      }
    loginWindow = controller
    controller.show()
  }

  func logOut() async {
    nextRenewal?.cancel()
    await WKWebsiteDataStore.default().removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
      modifiedSince: .distantPast
    )
    CookieVault.delete()
    CredentialVault.delete()
    problem = nil
    failures = 0
    state = .loginRequired
  }

  private func signIn(minutes: Int) async {
    failures = 0
    problem = await CookieVault.save() ? nil : .cookiesNotSaved
    state = .signedIn(minutesRemaining: minutes)
    schedule(after: Self.delayBeforeRenewal())
  }

  private func record(_ error: any Error) {
    Self.logger.error("Session renewal failed: \(error.localizedDescription, privacy: .public)")
    problem = CharbonProblem(error)
    failures += 1
  }

  static func delayBeforeRenewal() -> Duration {
    .seconds((renewalMinutes + Int.random(in: -jitterMinutes...jitterMinutes)) * 60)
  }

  private func schedule(after delay: Duration) {
    nextRenewal?.cancel()
    nextRenewal = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else {
        return
      }
      await self?.renewNow()
    }
  }
}
