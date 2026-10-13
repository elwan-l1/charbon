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
    case failed(String)
  }

  static let retryInterval: Duration = .seconds(5 * 60)

  // The jitter keeps the renewals from happening at a perfectly regular rhythm.
  private static let renewalMinutes = 60
  private static let jitterMinutes = 30
  private static let safetyMinutes = 30

  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "session")

  private(set) var state = State.unknown {
    didSet { onChange?(state) }
  }

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
      state = .signedIn(minutesRemaining: minutes)
      schedule(after: Self.delayBeforeRenewal(minutesRemaining: minutes))
      await CookieVault.save()
    } catch CharbonError.sessionExpired {
      Self.logger.notice("Session cannot be renewed, a login is required")
      state = .loginRequired
    } catch {
      Self.logger.error("Session renewal failed: \(error.localizedDescription, privacy: .public)")
      state = .failed(error.localizedDescription)
      schedule(after: Self.retryInterval)
    }
  }

  func showLogin() {
    let controller =
      loginWindow
      ?? LoginWindowController { [weak self] minutes in
        guard let self else {
          return
        }
        state = .signedIn(minutesRemaining: minutes)
        schedule(after: Self.delayBeforeRenewal(minutesRemaining: minutes))
        Task { await CookieVault.save() }
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
    state = .loginRequired
  }

  // The usual delay, unless the session would then be too close to its end: renew 30 minutes
  // before the end, or right away if that moment has already passed.
  static func delayBeforeRenewal(minutesRemaining: Int) -> Duration {
    let jitter = Int.random(in: -jitterMinutes...jitterMinutes)
    let usual = renewalMinutes + jitter
    let latest = max(0, minutesRemaining - safetyMinutes)
    return .seconds(min(usual, latest) * 60)
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
