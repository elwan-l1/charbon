import Foundation

package enum CharbonEnvironment {
  /// The host serving both the web app and its API.
  package static let host = "timbrage.hefr.ch"

  package static let baseURL = URL(string: "https://\(host)") ?? URL(fileURLWithPath: "/")

  package static let timesheetPageURL =
    URL(string: "https://\(host)/#/user/week/timesheet") ?? baseURL

  package static let identityProvider = "https://aai-logon.hes-so.ch/idp/shibboleth"

  package static let apiPath = "/TimbrageWebApi/api/"

  /// The Shibboleth page that reports the state of the current session.
  package static let sessionInfoPath = "/Shibboleth.sso/Session"

  /// A page that asks the identity provider for a fresh session.
  ///
  /// While the identity provider still remembers the user, loading this URL issues a new session
  /// without any prompt. Otherwise it ends on a login form.
  package static var renewalURL: URL {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path = "/Shibboleth.sso/Login"
    components?.queryItems = [
      URLQueryItem(name: "entityID", value: identityProvider),
      URLQueryItem(name: "target", value: baseURL.absoluteString + "/"),
    ]
    return components?.url ?? baseURL
  }
}
