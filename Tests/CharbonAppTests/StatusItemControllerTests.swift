import AppKit
import Testing

@testable import Charbon

@Suite("Status item")
@MainActor
struct StatusItemControllerTests {
  @Test("Offers About and Quit")
  func menu() throws {
    _ = NSApplication.shared
    let controller = StatusItemController()
    let menu = try #require(controller.menu)
    let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)
    #expect(titles == ["About Charbon", "Quit Charbon"])
  }
}
