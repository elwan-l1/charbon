import Testing

@testable import CharbonCore

@Suite("Charbon")
struct CharbonTests {
  @Test("Is called Charbon")
  func name() {
    #expect(Charbon.name == "Charbon")
  }
}
