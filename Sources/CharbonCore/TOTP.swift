import CryptoKit
import Foundation

/// The six-digit codes an authenticator app makes from a secret key (RFC 6238).
///
/// The secret is the base32 key or the `otpauth://` link that password managers keep.
package enum TOTP {
  private static let period: TimeInterval = 30
  private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

  /// The code for `date`, or nil when `secret` is not a base32 key.
  package static func code(secret: String, at date: Date) -> String? {
    guard let key = decode(key(in: secret)) else {
      return nil
    }
    var counter = UInt64(date.timeIntervalSince1970 / period).bigEndian
    let message = withUnsafeBytes(of: &counter) { Data($0) }
    let mac = Array(
      HMAC<Insecure.SHA1>.authenticationCode(for: message, using: SymmetricKey(data: key)))
    let offset = Int(mac[mac.count - 1] & 0x0f)
    let truncated =
      UInt32(mac[offset] & 0x7f) << 24 | UInt32(mac[offset + 1]) << 16
      | UInt32(mac[offset + 2]) << 8 | UInt32(mac[offset + 3])
    return String(format: "%06d", truncated % 1_000_000)
  }

  private static func key(in secret: String) -> String {
    guard
      secret.hasPrefix("otpauth://"),
      let items = URLComponents(string: secret)?.queryItems,
      let key = items.first(where: { $0.name == "secret" })?.value
    else {
      return secret
    }
    return key
  }

  // Authenticator apps show the key in groups, so spaces and dashes are skipped.
  private static func decode(_ secret: String) -> Data? {
    var bytes = [UInt8]()
    var buffer = 0
    var bits = 0
    for character in secret.uppercased() where !" -=".contains(character) {
      guard let value = alphabet.firstIndex(of: character) else {
        return nil
      }
      buffer = buffer << 5 | value
      bits += 5
      if bits >= 8 {
        bits -= 8
        bytes.append(UInt8((buffer >> bits) & 0xff))
        buffer &= (1 << bits) - 1
      }
    }
    return bytes.isEmpty ? nil : Data(bytes)
  }
}
