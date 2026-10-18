import CharbonCore
import Foundation

/// Text for durations and dates.
///
/// Dates are in English with the week starting on Monday, like the rest of the app.
@MainActor
enum Format {
  private static func formatter(_ pattern: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_GB")
    formatter.calendar = CharbonCalendar.calendar
    formatter.dateFormat = pattern
    return formatter
  }

  private static let weekdayShort = formatter("EEE")
  private static let weekdayLong = formatter("EEEE")
  private static let dayNumber = formatter("d")
  private static let dayMonth = formatter("d MMM")
  private static let longDate = formatter("EEEE d MMMM")
  private static let monthYear = formatter("MMMM yyyy")
  private static let monthName = formatter("MMMM")
  private static let dayMonthYear = formatter("d MMM yyyy")
  private static let fullDate = formatter("d MMMM yyyy")

  /// Minutes as `8:24`.
  static func hours(_ minutes: Int) -> String {
    let total = abs(minutes)
    let text = String(format: "%d:%02d", total / 60, total % 60)
    return minutes < 0 ? "−" + text : text
  }

  /// Minutes as `+0:57` or `−1:30`.
  static func signed(_ minutes: Int) -> String {
    minutes > 0 ? "+" + hours(minutes) : hours(minutes)
  }

  /// A share between 0 and 1 as `48%`.
  static func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
  }

  /// `of 42:00 · 66%`, or `nil` when nothing is expected.
  static func progress(done: Int, target: Int) -> String? {
    guard target > 0 else {
      return nil
    }
    return "of \(hours(target)) · \(percent(Double(done) / Double(target)))"
  }

  /// `49.50 CHF an hour`.
  static func rate(_ rate: Double) -> String {
    let amount = rate.formatted(.number.precision(.fractionLength(2)))
    return "\(amount) \(RateCalculator.currencyCode) an hour"
  }

  static func money(_ amount: Double) -> String {
    RateCalculator.format(amount)
  }

  static func weekdayShort(_ date: Date) -> String { weekdayShort.string(from: date) }
  static func weekdayLong(_ date: Date) -> String { weekdayLong.string(from: date) }
  static func dayNumber(_ date: Date) -> String { dayNumber.string(from: date) }
  static func dayMonth(_ date: Date) -> String { dayMonth.string(from: date) }
  static func longDate(_ date: Date) -> String { longDate.string(from: date) }
  static func fullDate(_ date: Date) -> String { fullDate.string(from: date) }
  static func monthYear(_ date: Date) -> String { monthYear.string(from: date) }
  static func monthName(_ date: Date) -> String { monthName.string(from: date) }

  /// `12 – 18 Oct 2026`.
  static func weekRange(containing date: Date) -> String {
    let start = CharbonCalendar.weekStart(of: date)
    let end = CharbonCalendar.addingDays(6, to: start)
    return "\(dayMonth.string(from: start)) – \(dayMonthYear.string(from: end))"
  }
}
