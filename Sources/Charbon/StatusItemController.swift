import AppKit
import CharbonCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let session: SessionController?
  private let timesheet: TimesheetController?

  private let sessionStatusItem = NSMenuItem()
  private let todayItem = NSMenuItem()
  private let weekItem = NSMenuItem()
  private let messageItem = NSMenuItem()
  private let clockInItem = NSMenuItem()
  private let clockOutItem = NSMenuItem()
  private let logInItem = NSMenuItem()
  private let logOutItem = NSMenuItem()

  var menu: NSMenu? {
    statusItem.menu
  }

  init(session: SessionController? = nil, timesheet: TimesheetController? = nil) {
    self.session = session
    self.timesheet = timesheet
    super.init()
    configureButton()
    configureMenu()
    update()
  }

  private func configureButton() {
    // The template image is drawn in the menu bar's own colour, light or dark.
    let image =
      NSImage(named: "MenuBarIcon")
      ?? NSImage(systemSymbolName: "flame", accessibilityDescription: Charbon.name)
    image?.isTemplate = true
    statusItem.button?.image = image
    statusItem.button?.setAccessibilityLabel(Charbon.name)
  }

  private func configureMenu() {
    let menu = NSMenu()
    menu.delegate = self
    menu.autoenablesItems = false

    if session != nil {
      for item in [sessionStatusItem, todayItem, weekItem, messageItem] {
        item.isEnabled = false
        menu.addItem(item)
      }
      menu.addItem(.separator())
      clockInItem.title = "Clock In"
      clockInItem.action = #selector(clockIn)
      clockOutItem.title = "Clock Out"
      clockOutItem.action = #selector(clockOut)
      logInItem.title = "Log In…"
      logInItem.action = #selector(logIn)
      logOutItem.title = "Log Out"
      logOutItem.action = #selector(logOut)
      for item in [clockInItem, clockOutItem, logInItem, logOutItem] {
        item.target = self
        menu.addItem(item)
      }
      menu.addItem(.separator())
    }

    let about = NSMenuItem(
      title: "About \(Charbon.name)",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    about.target = NSApp
    menu.addItem(about)
    menu.addItem(.separator())

    let quit = NSMenuItem(
      title: "Quit \(Charbon.name)",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    quit.target = NSApp
    menu.addItem(quit)

    statusItem.menu = menu
  }

  func menuWillOpen(_ menu: NSMenu) {
    timesheet?.refreshIfStale()
    update()
  }

  func update() {
    guard let session else {
      return
    }
    switch session.state {
    case .unknown, .checking:
      show("Checking session…")
    case .signedIn:
      showTimesheet()
    case .loginRequired:
      show(SessionStatus.signedOut.summary, logIn: true)
    case .failed(let message):
      show("Could not renew: \(message)", logIn: true)
    }
  }

  private func showTimesheet() {
    guard let snapshot = timesheet?.snapshot else {
      show("Logged in", message: timesheet?.message, logOut: true)
      return
    }
    let summary = StatusSummary.make(snapshot: snapshot, now: ClockTime(date: Date()))
    var working = false
    if case .working = snapshot.status {
      working = true
    }
    show(
      summary.headline,
      lines: summary.lines,
      message: timesheet?.message,
      clockIn: !working,
      clockOut: working,
      logOut: true
    )
  }

  private func show(
    _ status: String,
    lines: [String] = [],
    message: String? = nil,
    clockIn: Bool = false,
    clockOut: Bool = false,
    logIn: Bool = false,
    logOut: Bool = false
  ) {
    sessionStatusItem.title = status
    for (index, item) in [todayItem, weekItem].enumerated() {
      item.title = index < lines.count ? lines[index] : ""
      item.isHidden = index >= lines.count
    }
    messageItem.title = message ?? ""
    messageItem.isHidden = message == nil
    clockInItem.isHidden = !clockIn
    clockOutItem.isHidden = !clockOut
    logInItem.isHidden = !logIn
    logOutItem.isHidden = !logOut
    clockInItem.isEnabled = timesheet?.isBusy != true
    clockOutItem.isEnabled = timesheet?.isBusy != true
  }

  @objc private func clockIn() {
    guard let timesheet else {
      return
    }
    Task { await timesheet.clockIn() }
  }

  @objc private func clockOut() {
    guard let timesheet else {
      return
    }
    Task { await timesheet.clockOut() }
  }

  @objc private func logIn() {
    session?.showLogin()
  }

  @objc private func logOut() {
    guard let session else {
      return
    }
    Task { await session.logOut() }
  }
}
