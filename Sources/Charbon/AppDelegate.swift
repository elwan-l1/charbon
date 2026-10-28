import AppKit
import CharbonCore
import OSLog
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(subsystem: "ch.codevs.charbon", category: "application")

  // Checks only when the user asks: the Info.plist turns every automatic check off.
  private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
  private let session = SessionController()
  private let settings = SettingsModel()
  private lazy var timesheet = TimesheetController(session: session, settings: settings)
  private lazy var autoStamper = AutoStamper(
    settings: settings, session: session, timesheet: timesheet)
  private lazy var model = AppModel(session: session, timesheet: timesheet, settings: settings)
  private lazy var mainWindow = MainWindowController(model: model)
  private lazy var mainMenu = MainMenu(
    model: model, windows: mainWindow, updater: updaterController)
  private var statusItemController: StatusItemController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    applyAppearance()
    mainMenu.install()
    let statusItemController = StatusItemController(
      session: session,
      timesheet: timesheet,
      settings: settings,
      openWindow: { [weak self] in self?.mainWindow.show() },
      openSettings: { [weak self] in
        self?.model.screen = .settings
        self?.mainWindow.show()
      },
      updater: updaterController
    )
    self.statusItemController = statusItemController
    session.onChange = { [weak self] state in
      self?.model.sessionProblem = self?.session.problem
      self?.model.showsSessionContact = self?.session.showsContact ?? false
      self?.model.sessionState = state
      statusItemController.update()
      self?.timesheet.sessionChanged(to: state)
      if state.isSignedIn {
        self?.autoStamper.sessionSignedIn()
      }
    }
    timesheet.onChange = { statusItemController.update() }
    settings.onChange = { [weak self] in
      statusItemController.update()
      self?.applyAppearance()
    }
    settings.loadProjects = { [weak self] in try await self?.timesheet.projectChoices() ?? [] }
    NotificationCenter.default.addObserver(
      forName: .NSCalendarDayChanged, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in await self?.timesheet.refresh() }
    }
    session.start()
    autoStamper.start()
    mainWindow.show()
    Self.logger.info("Charbon is ready")
  }

  // The menu bar item keeps the app alive, so closing the window does not quit it.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    mainWindow.show()
    return true
  }

  private func applyAppearance() {
    switch settings.settings.appearance {
    case .system: NSApp.appearance = nil
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }
}
