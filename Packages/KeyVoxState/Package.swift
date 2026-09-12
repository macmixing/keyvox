// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxState",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "KeyVoxState", targets: ["KeyVoxState"])],
    targets: [
        .target(name: "KeyVoxState"),
        .target(name: "StateVerification", dependencies: ["KeyVoxState"], path: "Verification"),
        .executableTarget(name: "StateProbe", dependencies: ["StateVerification"], path: "Probe"),
        .testTarget(name: "KeyVoxStateTests", dependencies: ["StateVerification"]),
    ]
)
