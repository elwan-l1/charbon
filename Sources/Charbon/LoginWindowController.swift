import AppKit
import CharbonCore
import OSLog
import WebKit

@MainActor
final class LoginWindowController: NSObject, NSWindowDelegate, WKNavigationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "login")

  private let onSignedIn: (Int) -> Void

  private var window: NSWindow?
  private var webView: WKWebView?
  private var isVerifying = false
  private var retryTimer: Timer?

  init(onSignedIn: @escaping (Int) -> Void) {
    self.onSignedIn = onSignedIn
    super.init()
  }

  func show() {
    if let window {
      bringToFront(window)
      return
    }
    let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    webView.navigationDelegate = self
    webView.allowsBackForwardNavigationGestures = true
    self.webView = webView

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Log in to Timbrage"
    window.contentView = webView
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    self.window = window

    webView.load(URLRequest(url: CharbonEnvironment.timesheetPageURL))
    bringToFront(window)
    startRetrying()
  }

  func windowWillClose(_ notification: Notification) {
    retryTimer?.invalidate()
    retryTimer = nil
    window = nil
    webView?.navigationDelegate = nil
    webView = nil
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
    Task { await completeLoginIfPossible() }
  }

  // The site is a single-page app that keeps changing after the page has loaded, so one check
  // at load time can be too early.
  private func startRetrying() {
    retryTimer?.invalidate()
    retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else {
          return
        }
        Task { await self.completeLoginIfPossible() }
      }
    }
  }

  private func completeLoginIfPossible() async {
    guard
      !isVerifying,
      let webView,
      let url = webView.url,
      url.host == CharbonEnvironment.host,
      !url.path.hasPrefix("/Shibboleth.sso")
    else {
      return
    }
    isVerifying = true
    defer { isVerifying = false }
    let status = await SessionProbe.status(in: webView)
    guard case .active(let minutes)? = status else {
      Self.logger.notice("Not logged in yet: \(String(describing: status), privacy: .public)")
      return
    }
    Self.logger.notice("Login completed")
    window?.close()
    onSignedIn(minutes)
  }

  private func bringToFront(_ window: NSWindow) {
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
  }
}
