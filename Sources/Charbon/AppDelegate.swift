import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "application")

  private let session = SessionController()
  private lazy var timesheet = TimesheetController(session: session)
  private var statusItemController: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    MainMenu.install()
    let statusItemController = StatusItemController(session: session, timesheet: timesheet)
    self.statusItemController = statusItemController
    session.onChange = { [weak self] state in
      statusItemController.update()
      self?.timesheet.sessionChanged(to: state)
    }
    timesheet.onChange = { statusItemController.update() }
    session.start()
    Self.logger.info("Charbon is ready")
  }
}
