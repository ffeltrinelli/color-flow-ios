// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ColorFlow",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "ColorFlowCore", targets: ["ColorFlowCore"])],
    targets: [
        .target(name: "ColorFlowCore", resources: [.process("Resources")]),
        .executableTarget(name: "LevelCheck", dependencies: ["ColorFlowCore"]),
        .testTarget(name: "ColorFlowCoreTests", dependencies: ["ColorFlowCore"])
    ]
)
