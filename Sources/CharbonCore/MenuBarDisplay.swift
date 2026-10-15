import Foundation

/// What the menu bar shows next to the icon.
package enum MenuBarDisplay: String, Codable, CaseIterable, Sendable {
  case iconOnly
  case time
  case timeAndPercent
  case percent
  case timeAndMoney
  case money
  case remaining

  package var title: String {
    switch self {
    case .iconOnly: "Icon only"
    case .time: "Time worked"
    case .timeAndPercent: "Time worked and share of the day"
    case .percent: "Share of the day"
    case .timeAndMoney: "Time worked and earnings"
    case .money: "Earnings"
    case .remaining: "Time left today"
    }
  }

  package var example: String {
    switch self {
    case .iconOnly: "no text"
    case .time: "2h38"
    case .timeAndPercent: "2h38 (32%)"
    case .percent: "32%"
    case .timeAndMoney: "2h38 · 41 CHF"
    case .money: "41 CHF"
    case .remaining: "5h46 left"
    }
  }

  // `nil` means only the icon. Text shows while the user is clocked in or has worked today.
  // A choice that needs the day's target or an hourly rate shows the time worked until known.
  package func text(
    workedMinutes: Int,
    targetMinutes: Int?,
    hourlyRate: Double?,
    isWorking: Bool
  ) -> String? {
    guard self != .iconOnly, isWorking || workedMinutes > 0 else {
      return nil
    }
    let time = Self.compact(minutes: workedMinutes)
    let target = targetMinutes.flatMap { $0 > 0 ? $0 : nil }
    let percent = target.map { "\(Int((Double(workedMinutes) / Double($0) * 100).rounded()))%" }
    let money = hourlyRate.map {
      RateCalculator.format(RateCalculator.earnings(minutes: workedMinutes, rate: $0))
    }
    switch self {
    case .iconOnly:
      return nil
    case .time:
      return time
    case .timeAndPercent:
      return percent.map { "\(time) (\($0))" } ?? time
    case .percent:
      return percent ?? time
    case .timeAndMoney:
      return money.map { "\(time) · \($0)" } ?? time
    case .money:
      return money ?? time
    case .remaining:
      return target.map { "\(Self.compact(minutes: max($0 - workedMinutes, 0))) left" } ?? time
    }
  }

  /// Minutes as `2h38`.
  package static func compact(minutes: Int) -> String {
    let total = max(minutes, 0)
    return String(format: "%dh%02d", total / 60, total % 60)
  }
}
