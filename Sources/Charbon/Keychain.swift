import Foundation
import Security

enum Keychain {
  private static func identity(_ account: String) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: "ch.codevs.charbon",
      kSecAttrAccount: account,
    ]
  }

  static func load(account: String) -> Data? {
    var query = identity(account)
    query[kSecReturnData] = true
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
      return nil
    }
    return result as? Data
  }

  @discardableResult
  static func save(_ data: Data, account: String) -> Bool {
    delete(account: account)
    var item = identity(account)
    item[kSecValueData] = data
    // Readable after the first unlock, and never copied to another device.
    item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
  }

  static func delete(account: String) {
    SecItemDelete(identity(account) as CFDictionary)
  }
}
