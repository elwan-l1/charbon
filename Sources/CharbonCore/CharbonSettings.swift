import Foundation

package struct CharbonSettings: Codable, Equatable, Sendable {
  /// Where the worked hours are booked. `nil` books nothing.
  package var defaultProject: ProjectChoice?
  /// Hours per working day. `nil` uses the hours of the contract.
  package var dailyHoursOverride: Double?
  package var pay: PaySettings
  package var menuBarDisplay: MenuBarDisplay

  package init(
    defaultProject: ProjectChoice? = nil,
    dailyHoursOverride: Double? = nil,
    pay: PaySettings = PaySettings(),
    menuBarDisplay: MenuBarDisplay = .time
  ) {
    self.defaultProject = defaultProject
    self.dailyHoursOverride = dailyHoursOverride
    self.pay = pay
    self.menuBarDisplay = menuBarDisplay
  }

  private enum CodingKeys: String, CodingKey {
    case defaultProject, dailyHoursOverride, pay, menuBarDisplay
  }

  // Settings saved before a field existed must still load, with a default for that field.
  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = CharbonSettings()
    defaultProject = try? container.decodeIfPresent(ProjectChoice.self, forKey: .defaultProject)
    dailyHoursOverride = try? container.decodeIfPresent(Double.self, forKey: .dailyHoursOverride)
    pay = (try? container.decodeIfPresent(PaySettings.self, forKey: .pay)) ?? defaults.pay
    menuBarDisplay =
      (try? container.decodeIfPresent(MenuBarDisplay.self, forKey: .menuBarDisplay))
      ?? defaults.menuBarDisplay
  }

  /// The hours of a working week: the override over five days, else the hours of the contract.
  package func weeklyHours(contractMinutes: Int?) -> Double? {
    if let dailyHoursOverride, dailyHoursOverride > 0 {
      return dailyHoursOverride * 5
    }
    return contractMinutes.map { Double($0) / 60 }
  }

  package func hourlyRate(contractMinutes: Int?) -> Double? {
    RateCalculator.hourlyRate(pay: pay, weeklyHours: weeklyHours(contractMinutes: contractMinutes))
  }
}

package final class SettingsStore {
  private static let key = "settings.v1"

  private let defaults: UserDefaults

  package init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  package func load() -> CharbonSettings {
    guard
      let data = defaults.data(forKey: Self.key),
      let settings = try? JSONDecoder().decode(CharbonSettings.self, from: data)
    else {
      return CharbonSettings()
    }
    return settings
  }

  package func save(_ settings: CharbonSettings) {
    if let data = try? JSONEncoder().encode(settings) {
      defaults.set(data, forKey: Self.key)
    }
  }
}
