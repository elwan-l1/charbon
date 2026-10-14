import Foundation

/// A time of day with minute precision, as the API writes it (`07:50`).
package struct ClockTime: Hashable, Comparable, Sendable, CustomStringConvertible {
  package let minutes: Int

  package init(minutes: Int) {
    self.minutes = min(max(minutes, 0), 24 * 60 - 1)
  }

  package init?(_ string: String) {
    let parts = string.split(separator: ":", omittingEmptySubsequences: false)
    guard
      parts.count == 2,
      let hours = Int(parts[0]),
      let minutes = Int(parts[1]),
      (0..<24).contains(hours),
      (0..<60).contains(minutes)
    else {
      return nil
    }
    self.minutes = hours * 60 + minutes
  }

  package init(date: Date, calendar: Calendar = .current) {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    self.minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
  }

  package var description: String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
  }

  package static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
    lhs.minutes < rhs.minutes
  }
}
