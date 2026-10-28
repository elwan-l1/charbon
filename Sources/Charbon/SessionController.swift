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

  private let log = SessionLog.shared
  private let renewer = SessionRenewer()
  private var loginWindow: LoginWindowController?
  private var nextRenewal: Task<Void, Never>?
  private var isRenewing = false
  private var wakeObserver: (any NSObjectProtocol)?

  func start() {
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.log.add(.info, "The Mac woke up")
        await self?.renewNow()
      }
    }
    log.add(.info, "Charbon started")
    Task {
      await CookieVault.restore()
      await renewNow()
    }
  }

  func renewNow(because reason: String? = nil) async {
    guard !isRenewing else {
      return
    }
    isRenewing = true
    defer { isRenewing = false }
    nextRenewal?.cancel()
    state = .checking
    log.add(.info, "Renewing the session", reason.map { "Because \($0)." })
    let started = ContinuousClock.now
    do {
      let minutes = try await renewer.renew()
      Self.logger.notice("Session renewed, \(minutes) minutes left")
      log.add(
        .success, "Session renewed",
        "\(minutes) min left, took \(Self.seconds(since: started))")
      await signIn(minutes: minutes)
    } catch CharbonError.sessionExpired {
      Self.logger.notice("Session cannot be renewed, a login is required")
      log.add(.warning, "Logged out", "No saved login.")
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
    log.add(
      .info, "Testing the saved login", "In a separate web view. The session is left as it is.")
    let renewer = SessionRenewer(dataStore: .nonPersistent())
    let works = (try? await renewer.renew()) != nil
    log.add(works ? .success : .error, works ? "The saved login works" : "The saved login failed")
    return works
  }

  func showLogin() {
    log.add(.info, "Login window opened")
    let controller =
      loginWindow
      ?? LoginWindowController { [weak self] minutes in
        guard let self else {
          return
        }
        log.add(.success, "Logged in by hand", "\(minutes) min left")
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
    log.add(.info, "Logged out", "Cookies and saved login removed.")
    problem = nil
    failures = 0
    state = .loginRequired
  }

  private func signIn(minutes: Int) async {
    failures = 0
    problem = await CookieVault.save() ? nil : .cookiesNotSaved
    if let problem {
      log.add(.warning, problem.headline)
    }
    state = .signedIn(minutesRemaining: minutes)
    schedule(after: Self.delayBeforeRenewal())
  }

  private func record(_ error: any Error) {
    Self.logger.error("Session renewal failed: \(error.localizedDescription, privacy: .public)")
    problem = CharbonProblem(error)
    failures += 1
    log.add(.error, problem?.headline ?? error.localizedDescription, problem?.detail)
  }

  private static func seconds(since start: ContinuousClock.Instant) -> String {
    let duration = ContinuousClock.now - start
    let seconds =
      Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    return String(format: "%.1fs", seconds)
  }

  static func delayBeforeRenewal() -> Duration {
    .seconds((renewalMinutes + Int.random(in: -jitterMinutes...jitterMinutes)) * 60)
  }

  private func schedule(after delay: Duration) {
    nextRenewal?.cancel()
    if delay == Self.retryInterval {
      log.add(.info, "Retry in \(delay.components.seconds)s")
    } else {
      let time = Date().addingTimeInterval(Double(delay.components.seconds))
      log.add(.info, "Next renewal at \(time.formatted(.dateTime.hour().minute()))")
    }
    nextRenewal = Task { [weak self] in
      try? await Task.sleep(for: delay)
      guard !Task.isCancelled else {
        return
      }
      await self?.renewNow()
    }
  }
}
