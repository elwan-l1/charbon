import Foundation

/// Days, weeks and months the way Timbrage counts them: weeks start on Monday.
package enum CharbonCalendar {
  package static let calendar: Calendar = {
    var calendar = Calendar(identifier: .iso8601)
    calendar.timeZone = .current
    calendar.locale = .current
    return calendar
  }()

  /// Like `2026-10-12`.
  package static func dayKey(_ date: Date) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }

  /// The day a `yyyy-MM-dd` key stands for, at the start of the day.
  package static func date(fromKey key: String) -> Date? {
    let parts = key.prefix(10).split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
      return nil
    }
    return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }

  /// The Monday of the week that holds `date`.
  package static func weekStart(of date: Date) -> Date {
    calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
  }

  package static func monthStart(of date: Date) -> Date {
    calendar.dateInterval(of: .month, for: date)?.start ?? date
  }

  package static func addingDays(_ days: Int, to date: Date) -> Date {
    calendar.date(byAdding: .day, value: days, to: date) ?? date
  }

  package static func addingMonths(_ months: Int, to date: Date) -> Date {
    calendar.date(byAdding: .month, value: months, to: date) ?? date
  }

  /// The ISO number of the week, from 1 to 53.
  package static func weekNumber(of date: Date) -> Int {
    calendar.component(.weekOfYear, from: date)
  }

  /// Seven dates from the Monday of the week that holds `date`.
  package static func weekDates(containing date: Date) -> [Date] {
    let start = weekStart(of: date)
    return (0..<7).map { addingDays($0, to: start) }
  }
}
