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
  /// The Shibboleth session page did not look like one.
  case sessionPageUnreadable
  /// The saved login did not get through the identity provider.
  case autoLoginFailed(AutoLoginFailure)
}

/// Why the automatic login stopped.
package enum AutoLoginFailure: Equatable, Sendable {
  /// The password or the code was sent and the identity provider did not let the user in.
  case rejected
  /// The identity provider showed a page the autofill does not know.
  case unknownPage
  /// Too many failed tries: the autofill waits until the login is saved again.
  case paused
  /// The identity provider asked for a code and no authenticator key is saved.
  case needsCode
  /// Nothing happened in time.
  case timedOut
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
    case .sessionPageUnreadable:
      "The session page of Timbrage could not be read."
    case .autoLoginFailed:
      "The automatic login did not work."
    }
  }
}
