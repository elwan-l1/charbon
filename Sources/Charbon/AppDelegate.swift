import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "application")

  private var statusItemController: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    // A menu bar app: no Dock icon and no main window.
    NSApp.setActivationPolicy(.accessory)
    statusItemController = StatusItemController()
    Self.logger.info("Charbon is ready")
  }
}
