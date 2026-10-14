import Foundation

/// A signed duration written `H:mm` or `H:mm:ss`, like `8:24:00` or `-1:30:00`.
package struct HoursValue: Hashable, Comparable, Sendable, CustomStringConvertible {
  package let seconds: Int

  package init(seconds: Int) {
    self.seconds = seconds
  }

  package init(minutes: Int) {
    self.seconds = minutes * 60
  }

  package init?(_ string: String) {
    var text = string.filter { !$0.isWhitespace }
    var sign = 1
    if text.hasPrefix("-") {
      sign = -1
      text.removeFirst()
    }
    let parts = text.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2 || parts.count == 3 else {
      return nil
    }
    let numbers = parts.compactMap { Int($0) }
    guard numbers.count == parts.count, numbers.allSatisfy({ $0 >= 0 }) else {
      return nil
    }
    let seconds = numbers.count == 3 ? numbers[2] : 0
    self.seconds = sign * ((numbers[0] * 60 + numbers[1]) * 60 + seconds)
  }

  package var minutes: Int {
    seconds / 60
  }

  /// The `H:mm` form that the API takes when booking hours.
  package var formatted: String {
    let total = abs(minutes)
    let text = String(format: "%d:%02d", total / 60, total % 60)
    return seconds < 0 && total > 0 ? "-" + text : text
  }

  package var description: String {
    formatted
  }

  package static func < (lhs: HoursValue, rhs: HoursValue) -> Bool {
    lhs.seconds < rhs.seconds
  }
}
