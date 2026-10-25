import Foundation

/// What the identity provider asks for at login.
struct LoginCredentials: Codable, Equatable {
  var username: String
  var password: String
  // The base32 key behind the authenticator app code. Empty without that second factor.
  var totpSecret: String
}

/// Keeps the login in the Keychain so Charbon can sign in again when the identity provider forgot
/// the user.
enum CredentialVault {
  private static let account = "login-credentials"

  static func load() -> LoginCredentials? {
    Keychain.load(account: account).flatMap {
      try? JSONDecoder().decode(LoginCredentials.self, from: $0)
    }
  }

  @discardableResult
  static func save(_ credentials: LoginCredentials) -> Bool {
    guard let data = try? JSONEncoder().encode(credentials) else {
      return false
    }
    return Keychain.save(data, account: account)
  }

  static func delete() {
    Keychain.delete(account: account)
  }
}
