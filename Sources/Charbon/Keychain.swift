import Foundation
import Security

enum Keychain {
  private static var identity: [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "ch.codevs.charbon",
      kSecAttrAccount: "web-cookies",
    ]
  }

  static func load() -> Data? {
    var query = identity
    query[kSecReturnData] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
      return nil
    }
    return result as? Data
  }

  @discardableResult
  static func save(_ data: Data) -> Bool {
    delete()
    var item = identity
    item[kSecValueData] = data
    // Readable after the first unlock, and never copied to another device.
    item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
  }

  static func delete() {
    SecItemDelete(identity as CFDictionary)
  }
}
