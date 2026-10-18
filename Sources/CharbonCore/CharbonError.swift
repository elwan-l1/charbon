import Foundation

package enum CharbonError: Error, Equatable, Sendable {
  /// No Timbrage session is available.
  case notSignedIn
  /// The server no longer accepts the stored session.
  case sessionExpired
  /// The timesheet changed elsewhere: fetch the week again and retry.
  case staleData
  /// A clock in while a period is already open.
  case alreadyClockedIn(since: String)
  /// A clock out while no period is open.
  case notClockedIn
  case endsBeforeStart(arrival: String, departure: String)
  /// A change to a day that makes no sense, in words for the user.
  case invalidEdit(String)
  case startsBeforePreviousPeriod(previousDeparture: String)
  /// The fetched week does not contain today.
  case todayUnavailable
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
    case .staleData:
      "The timesheet changed elsewhere. Refresh and try again."
    case .alreadyClockedIn(let since):
      "You are already clocked in since \(since)."
    case .notClockedIn:
      "You are not clocked in."
    case .endsBeforeStart(let arrival, _):
      "The departure must be later than the arrival at \(arrival). Try again in a minute."
    case .invalidEdit(let reason):
      reason
    case .startsBeforePreviousPeriod(let previousDeparture):
      "An earlier period already ends at \(previousDeparture)."
    case .todayUnavailable:
      "Today was not found in the current week."
    case .network(let message):
      "Could not reach Timbrage: \(message)"
    case let .server(status, message):
      message.isEmpty ? "Timbrage answered with an error (HTTP \(status))." : message
    case .invalidResponse(let detail):
      "Timbrage sent an unexpected answer: \(detail)"
    }
  }
}
