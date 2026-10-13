import Foundation

package enum CharbonError: Error, Equatable, Sendable {
  /// No Timbrage session is available.
  case notSignedIn
  /// The server no longer accepts the stored session.
  case sessionExpired
  case network(String)
  case server(status: Int, message: String)
  case invalidResponse(String)
}

extension CharbonError: LocalizedError {
  package var errorDescription: String? {
    switch self {
    case .notSignedIn:
      "You are not logged in to Timbrage."
    case .sessionExpired:
      "Your Timbrage session has expired. Log in again."
    case .network(let message):
      "Could not reach Timbrage: \(message)"
    case let .server(status, message):
      message.isEmpty ? "Timbrage answered with an error (HTTP \(status))." : message
    case .invalidResponse(let detail):
      "Timbrage sent an unexpected answer: \(detail)"
    }
  }
}
