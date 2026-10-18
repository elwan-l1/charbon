import Foundation

/// What a text field holds once it is read.
package enum TimeInputResult<Value: Equatable & Sendable>: Equatable, Sendable {
  /// Nothing typed, which clears the time.
  case empty
  case value(Value)
  case invalid

  /// The value, or `nil` when the field is empty or cannot be read.
  package var valueOrNil: Value? {
    if case .value(let value) = self {
      return value
    }
    return nil
  }
}

/// Reads times and durations the way people type them.
package enum TimeInput {
  /// A time of day: `7:50`, `07:50`, `7.50`, `750`, `0750`, `7h50` or a bare hour like `8`.
  ///
  /// Three digits read as a two digit hour when that is a valid hour, so `112` is 11:20, and as a
  /// one digit hour otherwise, so `750` is 07:50.
  package static func clock(_ text: String) -> TimeInputResult<ClockTime> {
    let cleaned = text.filter { !$0.isWhitespace }.lowercased()
    guard !cleaned.isEmpty else {
      return .empty
    }
    guard let (hours, minutes) = split(cleaned, separators: ":.h", isClock: true),
      (0..<24).contains(hours), (0..<60).contains(minutes)
    else {
      return .invalid
    }
    return .value(ClockTime(minutes: hours * 60 + minutes))
  }

  /// A duration: `8:20`, `8h20`, `830`, a bare number of hours like `8`, or decimal hours like
  /// `8.5` or `8,5`.
  package static func duration(_ text: String) -> TimeInputResult<Int> {
    let cleaned = text.filter { !$0.isWhitespace }.lowercased()
    guard !cleaned.isEmpty else {
      return .empty
    }
    if cleaned.contains(where: { ".,".contains($0) }) {
      guard let hours = Double(cleaned.replacingOccurrences(of: ",", with: ".")), hours >= 0,
        hours < 24
      else {
        return .invalid
      }
      return .value(Int((hours * 60).rounded()))
    }
    guard let (hours, minutes) = split(cleaned, separators: ":h", isClock: false), hours < 24,
      minutes < 60
    else {
      return .invalid
    }
    return .value(hours * 60 + minutes)
  }

  // Hours and minutes around a separator, or from digits alone: `8` is 8:00, `830` is 8:30 and
  // `0830` is 8:30. In a time of day, `112` is 11:20: a single digit after a valid two digit hour
  // is the tens of the minutes.
  private static func split(_ text: String, separators: String, isClock: Bool) -> (Int, Int)? {
    if let index = text.firstIndex(where: { separators.contains($0) }) {
      let hours = text[..<index]
      let minutes = text[text.index(after: index)...]
      guard let hoursValue = Int(hours), hoursValue >= 0,
        minutes.isEmpty || (Int(minutes) ?? -1) >= 0
      else {
        return nil
      }
      return (hoursValue, Int(minutes) ?? 0)
    }
    guard text.allSatisfy(\.isNumber), let number = Int(text) else {
      return nil
    }
    switch text.count {
    case 1, 2: return (number, 0)
    case 3 where isClock && number / 10 < 24: return (number / 10, number % 10 * 10)
    case 3, 4: return (number / 100, number % 100)
    default: return nil
    }
  }
}
