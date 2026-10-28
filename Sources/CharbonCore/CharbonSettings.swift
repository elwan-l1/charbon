import Foundation

/// The colours of the app window.
package enum AppearanceMode: String, Codable, CaseIterable, Sendable {
  case system
  case light
  case dark

  package var title: String {
    switch self {
    case .system: "Match the system"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}

package struct CharbonSettings: Codable, Equatable, Sendable {
  /// Where the worked hours are booked. `nil` books nothing.
  package var defaultProject: ProjectChoice?
  /// Hours per working day. `nil` uses the hours of the contract.
  package var dailyHoursOverride: Double?
  package var pay: PaySettings
  package var menuBarDisplay: MenuBarDisplay
  package var appearance: AppearanceMode
  /// Whether the item next to the clock of the Mac is shown.
  package var showsMenuBarItem: Bool
  /// Whether the user went through the welcome tour, or skipped it.
  package var hasCompletedOnboarding: Bool
  package var autoStamp: AutoStampSettings

  package init(
    defaultProject: ProjectChoice? = nil,
    dailyHoursOverride: Double? = nil,
    pay: PaySettings = PaySettings(),
    menuBarDisplay: MenuBarDisplay = .time,
    appearance: AppearanceMode = .system,
    showsMenuBarItem: Bool = true,
    hasCompletedOnboarding: Bool = false,
    autoStamp: AutoStampSettings = AutoStampSettings()
  ) {
    self.defaultProject = defaultProject
    self.dailyHoursOverride = dailyHoursOverride
    self.pay = pay
    self.menuBarDisplay = menuBarDisplay
    self.appearance = appearance
    self.showsMenuBarItem = showsMenuBarItem
    self.hasCompletedOnboarding = hasCompletedOnboarding
    self.autoStamp = autoStamp
  }

  private enum CodingKeys: String, CodingKey {
    case defaultProject, dailyHoursOverride, pay, menuBarDisplay, appearance
    case showsMenuBarItem, hasCompletedOnboarding, autoStamp
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
    appearance =
      (try? container.decodeIfPresent(AppearanceMode.self, forKey: .appearance))
      ?? defaults.appearance
    showsMenuBarItem =
      (try? container.decodeIfPresent(Bool.self, forKey: .showsMenuBarItem))
      ?? defaults.showsMenuBarItem
    hasCompletedOnboarding =
      (try? container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding))
      ?? defaults.hasCompletedOnboarding
    autoStamp =
      (try? container.decodeIfPresent(AutoStampSettings.self, forKey: .autoStamp))
      ?? defaults.autoStamp
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
