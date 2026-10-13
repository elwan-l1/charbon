import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "application")

  private let session = SessionController()
  private var statusItemController: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    MainMenu.install()
    statusItemController = StatusItemController(session: session)
    session.start()
    Self.logger.info("Charbon is ready")
  }
}
