import AppKit
import CharbonCore
import SwiftUI

/// The main window of the app.
///
/// It stays alive when closed, so it comes back at once.
@MainActor
final class MainWindowController: NSObject {
  private let model: AppModel
  private var window: NSWindow?

  init(model: AppModel) {
    self.model = model
    super.init()
  }

  func show() {
    let window = window ?? makeWindow()
    self.window = window
    NSApp.activate()
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    window.makeKeyAndOrderFront(nil)
  }

  private func makeWindow() -> NSWindow {
    let host = NSHostingController(rootView: RootView(model: model))
    // the window keeps its own size, the content does not decide it
    host.sizingOptions = []
    let window = NSWindow(contentViewController: host)
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.title = Charbon.name
    window.isReleasedWhenClosed = false
    window.contentMinSize = NSSize(width: 960, height: 640)
    window.setContentSize(NSSize(width: 1120, height: 760))
    window.setFrameAutosaveName("CharbonMainWindow")
    if !window.setFrameUsingName("CharbonMainWindow") {
      window.center()
    }
    return window
  }
}
