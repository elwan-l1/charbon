import Foundation

package enum SessionStatus: Equatable, Sendable {
  case active(minutesRemaining: Int)
  case signedOut

  package var summary: String {
    switch self {
    case .active:
      "Logged in"
    case .signedOut:
      "Not logged in"
    }
  }

  /// Reads the Shibboleth session page, or returns `nil` when it is not that page.
  package static func parse(_ html: String) -> SessionStatus? {
    // The page is HTML, and a tag sits between the label and the number.
    let page = html.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    if page.contains("A valid session was not found") {
      return .signedOut
    }
    let pattern = #"Session Expiration \(barring inactivity\): (\d+) minute"#
    guard
      let match = page.range(of: pattern, options: .regularExpression),
      let minutes = Int(page[match].filter(\.isNumber))
    else {
      return nil
    }
    return .active(minutesRemaining: minutes)
  }
}
