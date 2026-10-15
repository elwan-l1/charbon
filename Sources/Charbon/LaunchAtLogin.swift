import OSLog
import ServiceManagement

/// Registers or unregisters the app as a login item. macOS keeps the state, not the app.
enum LaunchAtLogin {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "launch-at-login")

  static var isEnabled: Bool {
    SMAppService.mainApp.status == .enabled
  }

  static func apply(_ isEnabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if isEnabled {
        if service.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
        } else if service.status != .enabled {
          try service.register()
        }
      } else if service.status != .notRegistered {
        try service.unregister()
      }
    } catch {
      logger.error("Could not update launch at login: \(error.localizedDescription)")
    }
  }
}
