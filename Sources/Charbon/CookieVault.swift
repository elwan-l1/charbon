import Foundation
import OSLog
import WebKit

/// Keeps the web view's cookies between launches.
///
/// WebKit forgets cookies without an expiry date when the app quits, which would log the user
/// out of the identity provider at every launch. This saves all cookies to the Keychain and puts
/// them back at the next launch.
@MainActor
enum CookieVault {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "cookies")
  private static let account = "web-cookies"

  /// How long a cookie without an expiry date is kept once restored.
  ///
  /// The server still decides how long its session really lasts.
  private static let sessionCookieLifetime: TimeInterval = 7 * 24 * 3600

  private static var cookieStore: WKHTTPCookieStore {
    WKWebsiteDataStore.default().httpCookieStore
  }

  /// False when the cookies could not be kept.
  static func save() async -> Bool {
    let rows = await cookieStore.allCookies().map(row)
    guard
      let data = try? PropertyListSerialization.data(
        fromPropertyList: rows, format: .binary, options: 0),
      Keychain.save(data, account: account)
    else {
      logger.error("Could not save the cookies to the Keychain")
      return false
    }
    return true
  }

  static func restore() async {
    guard
      let data = Keychain.load(account: account),
      let rows = try? PropertyListSerialization.propertyList(from: data, format: nil)
        as? [[String: Any]]
    else {
      return
    }
    var count = 0
    for row in rows {
      if let cookie = cookie(from: row) {
        await cookieStore.setCookie(cookie)
        count += 1
      }
    }
    logger.notice("Restored \(count) cookies")
  }

  static func delete() {
    Keychain.delete(account: account)
  }

  // Keeps only the String and Date values, which a property list can hold.
  private static func row(_ cookie: HTTPCookie) -> [String: Any] {
    var row: [String: Any] = [:]
    for (key, value) in cookie.properties ?? [:] where value is String || value is Date {
      row[key.rawValue] = value
    }
    if cookie.isHTTPOnly {
      row["HttpOnly"] = "TRUE"
    }
    return row
  }

  private static func cookie(from row: [String: Any]) -> HTTPCookie? {
    var properties = Dictionary(
      uniqueKeysWithValues: row.map { (HTTPCookiePropertyKey($0.key), $0.value) })
    let expiry = properties[.expires] as? Date ?? Date(timeIntervalSinceNow: sessionCookieLifetime)
    guard expiry > .now else {
      return nil
    }
    properties[.discard] = nil
    properties[.expires] = expiry
    return HTTPCookie(properties: properties)
  }
}
