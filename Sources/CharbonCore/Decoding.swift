import Foundation

extension KeyedDecodingContainer {
  // The server leaves fields out or sends null, so a bad field falls back instead of failing.
  func lossy<T: Decodable>(_ key: Key, default defaultValue: T) -> T {
    (try? decodeIfPresent(T.self, forKey: key)) ?? defaultValue
  }
}
