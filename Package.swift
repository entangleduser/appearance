// swift-tools-version: 5.5
import PackageDescription

let package = Package(
 name: "Appearance",
 platforms: [.macOS(.v10_15)],
 products: [.library(name: "Appearance", targets: ["Appearance"])],
 targets: [
  .target(name: "Appearance"),
  .testTarget(name: "AppearanceTests", dependencies: ["Appearance"])
 ]
)
