import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "application")

  private let session = SessionController()
  private let settings = SettingsModel()
  private lazy var timesheet = TimesheetController(session: session, settings: settings)
  private lazy var settingsWindow = SettingsWindowController(model: settings)
  private var statusItemController: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    MainMenu.install()
    let statusItemController = StatusItemController(
      session: session,
      timesheet: timesheet,
      settings: settingsWindow
    )
    self.statusItemController = statusItemController
    session.onChange = { [weak self] state in
      statusItemController.update()
      self?.timesheet.sessionChanged(to: state)
    }
    timesheet.onChange = { statusItemController.update() }
    settings.onChange = { statusItemController.update() }
    settings.loadProjects = { [weak self] in try await self?.timesheet.projectChoices() ?? [] }
    session.start()
    Self.logger.info("Charbon is ready")
  }
}
