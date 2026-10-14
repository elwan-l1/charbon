import AppKit
import CharbonCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  let model: SettingsModel
  private var window: NSWindow?

  init(model: SettingsModel) {
    self.model = model
    super.init()
  }

  func show() {
    if window == nil {
      let window = NSWindow(
        contentViewController: NSHostingController(rootView: SettingsView(model: model)))
      window.title = "\(Charbon.name) Settings"
      window.styleMask = [.titled, .closable, .miniaturizable]
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      self.window = window
    }
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
  }
}
