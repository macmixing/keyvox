// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "KeyVoxAndroidEngine",
    platforms: [.macOS(.v13)],
    products: [.library(name: "KeyVoxAndroidEngine", type: .dynamic, targets: ["KeyVoxAndroidEngine"])],
    dependencies: [
        .package(path: "../../Packages/KeyVoxCore"),
        .package(path: "../../Packages/KeyVoxTextComposition"),
        .package(path: "../../Packages/KeyVoxModels"),
        .package(path: "../../Packages/KeyVoxWhisper"),
        .package(path: "../../Packages/KeyVoxVoiceActivity")
    ],
    targets: [
        .target(name: "KeyVoxAndroidEngine", dependencies: ["CAndroidEngine",
            .product(name: "KeyVoxCore", package: "KeyVoxCore"),
            .product(name: "KeyVoxTextComposition", package: "KeyVoxTextComposition"),
            .product(name: "KeyVoxModels", package: "KeyVoxModels"),
            .product(name: "KeyVoxWhisper", package: "KeyVoxWhisper"),
            .product(name: "KeyVoxVoiceActivity", package: "KeyVoxVoiceActivity")]),
        .target(name: "CAndroidEngine", linkerSettings: [.linkedLibrary("android"), .linkedLibrary("log")])
    ])
