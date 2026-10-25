import Foundation

/// An error the user may have to report: a code and one short sentence, never a stack.
package struct CharbonProblem: Equatable, Sendable {
  package let code: Int
  package let summary: String
  /// A few more words for the maintainer, in the mail only.
  package let detail: String?
  /// Gone by itself in a moment, like a network that is not back yet.
  package let isTransient: Bool

  package static let cookiesNotSaved = CharbonProblem(
    code: 3001, summary: "The session could not be saved in the Keychain.")

  package static let loginNotSaved = CharbonProblem(
    code: 3002, summary: "The login could not be saved in the Keychain.")

  package var headline: String {
    "Error \(code): \(summary)"
  }

  package init(code: Int, summary: String, detail: String? = nil, isTransient: Bool = false) {
    self.code = code
    self.summary = summary
    self.detail = detail.map { String($0.prefix(160)) }
    self.isTransient = isTransient
  }

  /// The problem behind `error`, or `nil` when it is a mistake the user can fix, like a time
  /// that is not allowed.
  package init?(_ error: any Error) {
    if error is CancellationError {
      return nil
    }
    guard let error = error as? CharbonError else {
      self.init(
        code: 5000, summary: "Something unexpected went wrong.", detail: "\(type(of: error))")
      return
    }
    switch error {
    case .notSignedIn, .sessionExpired, .staleData, .alreadyClockedIn, .notClockedIn,
      .endsBeforeStart, .invalidEdit, .startsBeforePreviousPeriod:
      return nil
    case .network(let message):
      self.init(
        code: 1001, summary: "Timbrage or edu-ID could not be reached.", detail: message,
        isTransient: true)
    case .sessionPageUnreadable:
      self.init(code: 1002, summary: "The session page of Timbrage could not be read.")
    case .autoLoginFailed(let failure):
      self.init(failure)
    case let .server(status, message):
      self.init(
        code: 4002, summary: "Timbrage answered with an error (HTTP \(status)).", detail: message)
    case .invalidResponse(let detail):
      self.init(code: 4003, summary: "Timbrage sent an answer Charbon cannot read.", detail: detail)
    case .todayUnavailable:
      self.init(code: 4004, summary: "Today was not found in the week Timbrage sent.")
    }
  }

  private init(_ failure: AutoLoginFailure) {
    switch failure {
    case .rejected:
      self.init(code: 2001, summary: "edu-ID did not accept the saved login.")
    case .unknownPage:
      self.init(code: 2002, summary: "edu-ID showed a page Charbon does not know.")
    case .paused:
      self.init(
        code: 2003,
        summary: "The automatic login is paused after failed tries. Save the login again.")
    case .needsCode:
      self.init(
        code: 2004, summary: "edu-ID asked for a code, and no authenticator key is saved.")
    case .timedOut:
      self.init(code: 2005, summary: "edu-ID did not answer in time.", isTransient: true)
    }
  }

  /// A mail to the maintainer that already says what happened.
  package func mailURL(appVersion: String, system: String) -> URL? {
    var lines = ["Hello,", "", "Charbon showed me an error.", ""]
    lines += ["Error: \(code)", "Message: \(summary)"]
    if let detail {
      lines.append("Detail: \(detail)")
    }
    lines += ["Charbon: \(appVersion)", "macOS: \(system)", ""]
    lines += ["What I was doing:", "", "(Never put a password in this mail.)"]
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = Charbon.maintainerEmail
    components.queryItems = [
      URLQueryItem(name: "subject", value: "Charbon error \(code)"),
      URLQueryItem(name: "body", value: lines.joined(separator: "\n")),
    ]
    return components.url
  }
}
