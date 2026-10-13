import AppKit
import CharbonCore

/// The app's item in the macOS menu bar and its menu.
@MainActor
final class StatusItemController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  var menu: NSMenu? {
    statusItem.menu
  }

  override init() {
    super.init()
    configureButton()
    configureMenu()
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
}
