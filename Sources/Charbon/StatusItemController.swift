import AppKit
import CharbonCore

@MainActor
final class StatusItemController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let session: SessionController?

  private let sessionStatusItem = NSMenuItem()
  private let logInItem = NSMenuItem()
  private let logOutItem = NSMenuItem()

  var menu: NSMenu? {
    statusItem.menu
  }

  init(session: SessionController? = nil) {
    self.session = session
    super.init()
    configureButton()
    configureMenu()
    session?.onChange = { [weak self] _ in self?.refreshSessionItems() }
    refreshSessionItems()
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

    if session != nil {
      sessionStatusItem.isEnabled = false
      logInItem.title = "Log In…"
      logInItem.action = #selector(logIn)
      logOutItem.title = "Log Out"
      logOutItem.action = #selector(logOut)
      for item in [logInItem, logOutItem] {
        item.target = self
      }
      for item in [sessionStatusItem, logInItem, logOutItem] {
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

  private func refreshSessionItems() {
    guard let session else {
      return
    }
    switch session.state {
    case .unknown, .checking:
      show("Checking session…", logIn: false, logOut: false)
    case .signedIn:
      show("Logged in", logIn: false, logOut: true)
    case .loginRequired:
      show(SessionStatus.signedOut.summary, logIn: true, logOut: false)
    case .failed(let message):
      show("Could not renew: \(message)", logIn: true, logOut: false)
    }
  }

  private func show(_ status: String, logIn: Bool, logOut: Bool) {
    sessionStatusItem.title = status
    logInItem.isHidden = !logIn
    logOutItem.isHidden = !logOut
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
