import AppKit
import CharbonCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let session: SessionController?
  private let timesheet: TimesheetController?
  private let settings: SettingsModel?
  private let openWindow: (() -> Void)?
  private let openSettingsScreen: (() -> Void)?

  private let sessionStatusItem = NSMenuItem()
  private let lineItems = (0..<3).map { _ in NSMenuItem() }
  private let messageItem = NSMenuItem()
  private let clockInItem = NSMenuItem()
  private let clockOutItem = NSMenuItem()
  private let settingsItem = NSMenuItem()
  private let logInItem = NSMenuItem()
  private let logOutItem = NSMenuItem()
  private let contactItem = NSMenuItem()
  private var tick: Timer?

  var menu: NSMenu? {
    statusItem.menu
  }

  init(
    session: SessionController? = nil,
    timesheet: TimesheetController? = nil,
    settings: SettingsModel? = nil,
    openWindow: (() -> Void)? = nil,
    openSettings: (() -> Void)? = nil
  ) {
    self.session = session
    self.timesheet = timesheet
    self.settings = settings
    self.openWindow = openWindow
    self.openSettingsScreen = openSettings
    super.init()
    configureButton()
    configureMenu()
    update()
    // keeps the time next to the icon live
    let tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.update() }
    }
    tick.tolerance = 5
    self.tick = tick
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
      let open = NSMenuItem(
        title: "Open \(Charbon.name)", action: #selector(showWindow), keyEquivalent: "")
      open.target = self
      menu.addItem(open)
      menu.addItem(.separator())
      for item in [sessionStatusItem] + lineItems + [messageItem] {
        item.isEnabled = false
        menu.addItem(item)
      }
      menu.addItem(.separator())
      clockInItem.title = "Clock In"
      clockInItem.action = #selector(clockIn)
      clockOutItem.title = "Clock Out"
      clockOutItem.action = #selector(clockOut)
      settingsItem.title = "Settings…"
      settingsItem.action = #selector(openSettings)
      settingsItem.keyEquivalent = ","
      if #available(macOS 27, *) {
        // AppKit adds a gear to the standard Settings item on its own
        settingsItem.preferredImageVisibility = .hidden
      }
      logInItem.title = "Log In…"
      logInItem.action = #selector(logIn)
      logOutItem.title = "Log Out"
      logOutItem.action = #selector(logOut)
      for item in [clockInItem, clockOutItem] {
        item.target = self
        menu.addItem(item)
      }
      menu.addItem(.separator())
      contactItem.title = "Contact the Maintainer…"
      contactItem.action = #selector(contactMaintainer)
      for item in [logInItem, logOutItem, contactItem, settingsItem] {
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
    statusItem.isVisible = settings?.settings.showsMenuBarItem ?? true
    switch session.state {
    case .unknown, .checking:
      show("Checking session…")
    case .signedIn:
      showTimesheet()
    case .loginRequired:
      show(session.problem?.headline ?? SessionStatus.signedOut.summary, logIn: true)
    case .failed:
      show(session.problem?.headline ?? "Could not renew the session", logIn: true)
    }
    contactItem.isHidden = !session.showsContact
  }

  private func showTimesheet() {
    guard let snapshot = timesheet?.snapshot else {
      show("Logged in", message: timesheet?.message, logOut: true)
      return
    }
    let summary = StatusSummary.make(
      snapshot: snapshot,
      now: ClockTime(date: Date()),
      settings: settings?.settings ?? CharbonSettings()
    )
    var working = false
    if case .working = snapshot.status {
      working = true
    }
    show(
      summary.headline,
      lines: summary.lines,
      barTitle: summary.barTitle,
      message: timesheet?.message,
      clockIn: !working,
      clockOut: working,
      logOut: true
    )
  }

  private func show(
    _ status: String,
    lines: [String] = [],
    barTitle: String? = nil,
    message: String? = nil,
    clockIn: Bool = false,
    clockOut: Bool = false,
    logIn: Bool = false,
    logOut: Bool = false
  ) {
    sessionStatusItem.title = status
    statusItem.button?.title = barTitle.map { " " + $0 } ?? ""
    statusItem.button?.imagePosition = barTitle == nil ? .imageOnly : .imageLeading
    for (index, item) in lineItems.enumerated() {
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

  @objc private func showWindow() {
    openWindow?()
  }

  @objc private func openSettings() {
    openSettingsScreen?()
  }

  @objc private func contactMaintainer() {
    guard let problem = session?.problem, let url = ContactMail.url(for: problem) else {
      return
    }
    NSWorkspace.shared.open(url)
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
