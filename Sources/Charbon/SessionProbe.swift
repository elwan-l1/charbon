import CharbonCore
import OSLog
import WebKit

/// Reads the session state through a web view, which holds the HttpOnly session cookie.
@MainActor
enum SessionProbe {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "probe")

  private static let script = """
    const response = await fetch('\(CharbonEnvironment.sessionInfoPath)', {credentials: 'include'});
    return await response.text();
    """

  // The fetch is relative, so the web view has to be on the Timbrage origin.
  static func status(in webView: WKWebView) async -> SessionStatus? {
    do {
      let result = try await webView.callAsyncJavaScript(script, contentWorld: .page)
      let page = result as? String
      return page.flatMap(SessionStatus.parse)
    } catch {
      logger.notice("Probe failed: \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }
}
