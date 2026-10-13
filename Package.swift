// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "CharbonCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "CharbonCore", targets: ["CharbonCore"])
  ],
  targets: [
    .target(name: "CharbonCore", path: "Sources/CharbonCore"),
    .testTarget(
      name: "CharbonTests",
      dependencies: ["CharbonCore"],
      path: "Tests/CharbonTests"
    ),
  ]
)
