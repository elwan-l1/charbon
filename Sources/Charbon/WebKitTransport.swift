import CharbonCore
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
    if let url = request.url {
      let cookies = await Self.cookies(for: url)
      for (name, value) in HTTPCookie.requestHeaderFields(with: cookies) {
        request.setValue(value, forHTTPHeaderField: name)
      }
    }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw CharbonError.invalidResponse("not an HTTP response")
    }
    return (data, http)
  }

  @MainActor
  private static func cookies(for url: URL) async -> [HTTPCookie] {
    await WKWebsiteDataStore.default().httpCookieStore.allCookies().filter { cookie in
      let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
      let host = url.host ?? ""
      return (host == domain || host.hasSuffix("." + domain))
        && url.path.hasPrefix(cookie.path)
        && (!cookie.isSecure || url.scheme == "https")
    }
  }
}
