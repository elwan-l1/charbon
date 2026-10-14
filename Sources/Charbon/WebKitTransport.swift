import CharbonCore
import OSLog
import WebKit

// Refuses redirects, so that a redirect to the login page is seen as one.
private final class RedirectBlocker: NSObject, URLSessionTaskDelegate, Sendable {
  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

/// Sends requests with the cookies of the login web view.
///
/// The session cookie is HttpOnly, so only the web view's cookie store can read it.
final class WebKitTransport: HTTPTransport {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "api")

  private let session: URLSession

  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieAcceptPolicy = .never
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 20
    session = URLSession(
      configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    var request = request
    var cookieNames: [String] = []
    if let url = request.url {
      let cookies = await Self.cookies(for: url)
      cookieNames = cookies.map(\.name)
      for (name, value) in HTTPCookie.requestHeaderFields(with: cookies) {
        request.setValue(value, forHTTPHeaderField: name)
      }
    }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw CharbonError.invalidResponse("not an HTTP response")
    }
    if !(200..<300).contains(http.statusCode) || http.mimeType == "text/html" {
      // only the shape of the answer, never the body: it can hold personal data
      let redirect = http.value(forHTTPHeaderField: "Location").flatMap(URL.init(string:))?.host
      let summary = [
        "HTTP \(http.statusCode) on \(request.url?.path ?? "?")",
        "type \(http.mimeType ?? "-")",
        "redirect \(redirect ?? "-")",
        "cookies \(cookieNames.joined(separator: ","))",
      ].joined(separator: "; ")
      Self.logger.notice("\(summary, privacy: .public)")
    }
    return (data, http)
  }

  /// The value of a cookie the web view holds for Timbrage, such as the readable `NoAGE`.
  static func cookieValue(named name: String) async -> String? {
    await cookies(for: CharbonEnvironment.baseURL).first { $0.name == name }?.value
  }

  @MainActor
  private static func cookies(for url: URL) async -> [HTTPCookie] {
    await WKWebsiteDataStore.default().httpCookieStore.allCookies().filter { cookie in
      let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
      let host = url.host ?? ""
      // the base URL has no path, which still means "/"
      let path = url.path.isEmpty ? "/" : url.path
      return (host == domain || host.hasSuffix("." + domain))
        && path.hasPrefix(cookie.path)
        && (!cookie.isSecure || url.scheme == "https")
    }
  }
}
