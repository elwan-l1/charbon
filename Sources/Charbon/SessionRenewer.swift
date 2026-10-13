import CharbonCore
import WebKit

/// Asks the identity provider for a fresh session in a hidden web view.
///
/// The web view shares its cookies with the login window, so a renewal works for as long as the
/// identity provider remembers the user.
@MainActor
final class SessionRenewer: NSObject, WKNavigationDelegate {
  // A login form never reaches the Timbrage page, so waiting this long means a login is needed.
  private static let timeout: Duration = .seconds(20)

  private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
  private var landing: CheckedContinuation<Bool, Never>?
  private var timeoutTask: Task<Void, Never>?
  private var navigationError: String?

  override init() {
    super.init()
    webView.navigationDelegate = self
  }

  func renew() async throws -> Int {
    navigationError = nil
    webView.load(URLRequest(url: CharbonEnvironment.renewalURL))
    let landed = await waitForLanding()
    if let navigationError {
      throw CharbonError.network(navigationError)
    }
    guard landed else {
      throw CharbonError.sessionExpired
    }
    switch await SessionProbe.status(in: webView) {
    case .active(let minutes)?:
      return minutes
    case .signedOut?:
      throw CharbonError.sessionExpired
    case nil:
      throw CharbonError.invalidResponse("The session page could not be read.")
    }
  }

  private func waitForLanding() async -> Bool {
    await withCheckedContinuation { continuation in
      landing = continuation
      timeoutTask = Task { [weak self] in
        try? await Task.sleep(for: Self.timeout)
        self?.finishLanding(false)
      }
    }
  }

  private func finishLanding(_ landed: Bool) {
    timeoutTask?.cancel()
    timeoutTask = nil
    landing?.resume(returning: landed)
    landing = nil
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
    guard let url = webView.url else {
      return
    }
    if url.host == CharbonEnvironment.host, !url.path.hasPrefix("/Shibboleth.sso") {
      finishLanding(true)
    } else if url.host == "wayf.switch.ch" {
      finishLanding(false)
    }
  }

  func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?,
    withError error: any Error
  ) {
    navigationError = error.localizedDescription
    finishLanding(false)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: any Error)
  {
    navigationError = error.localizedDescription
    finishLanding(false)
  }
}
