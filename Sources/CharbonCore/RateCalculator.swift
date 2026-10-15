import Foundation

package enum SalaryPeriod: String, Codable, CaseIterable, Sendable {
  case monthly
  case yearly
}

package enum RateMode: String, Codable, CaseIterable, Sendable {
  /// The rate comes from the salary and the weekly hours.
  case salary
  /// The rate is the one the user typed.
  case hourlyRate
}

package struct PaySettings: Codable, Equatable, Sendable {
  package var mode: RateMode
  package var salaryAmount: Double
  package var salaryPeriod: SalaryPeriod
  /// Payments per year of a monthly salary, 12 or 13.
  package var installmentsPerYear: Int
  package var hourlyRate: Double

  package init(
    mode: RateMode = .salary,
    salaryAmount: Double = 0,
    salaryPeriod: SalaryPeriod = .monthly,
    installmentsPerYear: Int = 12,
    hourlyRate: Double = 0
  ) {
    self.mode = mode
    self.salaryAmount = salaryAmount
    self.salaryPeriod = salaryPeriod
    self.installmentsPerYear = installmentsPerYear
    self.hourlyRate = hourlyRate
  }
}

/// Turns a salary and working time into an hourly rate and earnings.
package enum RateCalculator {
  // HES-SO pays in Swiss francs.
  package static let currencyCode = "CHF"
  package static let weeksPerYear = 52.0

  package static func annualSalary(_ pay: PaySettings) -> Double? {
    guard pay.salaryAmount > 0 else {
      return nil
    }
    switch pay.salaryPeriod {
    case .yearly:
      return pay.salaryAmount
    case .monthly:
      return pay.salaryAmount * Double(max(pay.installmentsPerYear, 1))
    }
  }

  // With a salary: the salary of a year divided by the hours of a year (`weeklyHours` × 52).
  // `nil` when it cannot be worked out.
  package static func hourlyRate(pay: PaySettings, weeklyHours: Double?) -> Double? {
    switch pay.mode {
    case .hourlyRate:
      return pay.hourlyRate > 0 ? pay.hourlyRate : nil
    case .salary:
      guard let annual = annualSalary(pay), let weeklyHours, weeklyHours > 0 else {
        return nil
      }
      return annual / (weeklyHours * weeksPerYear)
    }
  }

  package static func earnings(minutes: Int, rate: Double) -> Double {
    Double(minutes) / 60 * rate
  }

  /// Whole francs, rounded to the nearest, with the currency after: `122 CHF`.
  package static func format(_ amount: Double) -> String {
    let rounded = amount.formatted(
      .number.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero)
    )
    return "\(rounded) \(currencyCode)"
  }
}
