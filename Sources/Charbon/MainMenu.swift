import AppKit
import CharbonCore
import Sparkle

/// The menu of the app.
///
/// Its items move through the screens and run the clock.
@MainActor
final class MainMenu: NSObject {
  private let model: AppModel
  private let windows: MainWindowController
  private let updater: SPUStandardUpdaterController

  init(model: AppModel, windows: MainWindowController, updater: SPUStandardUpdaterController) {
    self.model = model
    self.windows = windows
    self.updater = updater
    super.init()
  }

  func install() {
    let mainMenu = NSMenu()
    mainMenu.addItem(submenuItem(appMenu()))
    mainMenu.addItem(submenuItem(clockMenu()))
    mainMenu.addItem(submenuItem(editMenu()))
    mainMenu.addItem(submenuItem(viewMenu()))
    let window = windowMenu()
    mainMenu.addItem(submenuItem(window))
    NSApp.mainMenu = mainMenu
    NSApp.windowsMenu = window
  }

  private func submenuItem(_ menu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem()
    item.submenu = menu
    return item
  }

  private func item(
    _ title: String,
    _ action: Selector,
    _ key: String = "",
    modifiers: NSEvent.ModifierFlags = [.command]
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = modifiers
    item.target = self
    return item
  }

  private func appMenu() -> NSMenu {
    let menu = NSMenu(title: Charbon.name)
    menu.addItem(
      withTitle: "About \(Charbon.name)",
      action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
      keyEquivalent: ""
    )
    let updates = menu.addItem(
      withTitle: "Check for Updates…",
      action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
      keyEquivalent: ""
    )
    updates.target = updater
    menu.addItem(.separator())
    menu.addItem(item("Settings…", #selector(openSettings), ","))
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Hide \(Charbon.name)", action: #selector(NSApplication.hide(_:)),
      keyEquivalent: "h")
    let others = menu.addItem(
      withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h")
    others.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(
      withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)),
      keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit \(Charbon.name)", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    return menu
  }

  private func clockMenu() -> NSMenu {
    let menu = NSMenu(title: "Clock")
    menu.addItem(
      item("Clock In or Out", #selector(toggleClock), "\r", modifiers: [.command, .option]))
    return menu
  }

  private func editMenu() -> NSMenu {
    let menu = NSMenu(title: "Edit")
    menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    menu.addItem(.separator())
    menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    menu.addItem(
      withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    return menu
  }

  private func viewMenu() -> NSMenu {
    let menu = NSMenu(title: "View")
    menu.addItem(item("Today", #selector(showToday), "1"))
    menu.addItem(item("Week", #selector(showWeek), "2"))
    menu.addItem(item("Month", #selector(showMonth), "3"))
    menu.addItem(.separator())
    menu.addItem(item("Previous", #selector(previous), "["))
    menu.addItem(item("Next", #selector(next), "]"))
    menu.addItem(item("Go to Today", #selector(goToCurrent), "t"))
    menu.addItem(.separator())
    menu.addItem(item("Refresh", #selector(refresh), "r"))
    return menu
  }

  private func windowMenu() -> NSMenu {
    let menu = NSMenu(title: "Window")
    menu.addItem(
      withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"
    )
    menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
    menu.addItem(.separator())
    menu.addItem(item("\(Charbon.name)", #selector(showWindow), "0"))
    return menu
  }

  @objc private func openSettings() { go(.settings) }
  @objc private func showWindow() { windows.show() }
  @objc private func showToday() { go(.today) }
  @objc private func showWeek() { go(.week) }
  @objc private func showMonth() { go(.month) }
  @objc private func previous() { model.step(-1) }
  @objc private func next() { model.step(1) }
  @objc private func goToCurrent() { model.goToCurrent() }
  @objc private func refresh() { model.refresh() }

  private func go(_ screen: Screen) {
    model.screen = screen
    windows.show()
  }

  @objc private func toggleClock() {
    guard let snapshot = model.timesheet.snapshot else {
      return
    }
    let timesheet = model.timesheet
    Task {
      if case .working = snapshot.status {
        await timesheet.clockOut()
      } else {
        await timesheet.clockIn()
      }
    }
  }
}
