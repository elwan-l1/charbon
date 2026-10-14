import Foundation

package struct CharbonSettings: Codable, Equatable, Sendable {
  /// Where the worked hours are booked. `nil` books nothing.
  package var defaultProject: ProjectChoice?
  /// Hours per working day. `nil` uses the hours of the contract.
  package var dailyHoursOverride: Double?

  package init(defaultProject: ProjectChoice? = nil, dailyHoursOverride: Double? = nil) {
    self.defaultProject = defaultProject
    self.dailyHoursOverride = dailyHoursOverride
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
