// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "TubeBackdrop",
  platforms: [.macOS(.v13)],
  products: [
    .executable(name: "TubeBackdrop", targets: ["TubeBackdrop"])
  ],
  targets: [
    .executableTarget(
      name: "TubeBackdrop",
      path: "Sources/TubeBackdrop"
    )
  ]
)
