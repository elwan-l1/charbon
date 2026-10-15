import CharbonCore
import Observation

/// The settings, saved as they change, and the projects the picker lists.
@MainActor
@Observable
final class SettingsModel {
  var settings: CharbonSettings
  var projects: [ProjectChoice] = []
  var isLoadingProjects = false
  var projectsError: String?
  var launchAtLogin = LaunchAtLogin.isEnabled

  @ObservationIgnored private let store: SettingsStore
  @ObservationIgnored var loadProjects: () async throws -> [ProjectChoice] = { [] }
  @ObservationIgnored var onChange: (() -> Void)?

  init(store: SettingsStore = SettingsStore()) {
    self.store = store
    settings = store.load()
  }

  /// Turns it on or off, then shows what macOS really did: it may ask for approval first.
  func setLaunchAtLogin(_ isEnabled: Bool) {
    LaunchAtLogin.apply(isEnabled)
    refreshLaunchAtLogin()
  }

  /// The user can also change it in System Settings.
  func refreshLaunchAtLogin() {
    launchAtLogin = LaunchAtLogin.isEnabled
  }

  func commit() {
    store.save(settings)
    onChange?()
  }

  func loadProjectsIfNeeded() async {
    guard projects.isEmpty else {
      return
    }
    await reloadProjects()
  }

  func reloadProjects() async {
    guard !isLoadingProjects else {
      return
    }
    isLoadingProjects = true
    projectsError = nil
    defer { isLoadingProjects = false }
    do {
      projects = try await loadProjects()
    } catch {
      projectsError = error.localizedDescription
    }
  }

  /// Projects that contain every word of `query`.
  func matches(for query: String) -> [ProjectChoice] {
    let words = query.split(separator: " ").map(String.init)
    return projects.filter { choice in
      words.allSatisfy { choice.displayName.localizedCaseInsensitiveContains($0) }
    }
  }
}
