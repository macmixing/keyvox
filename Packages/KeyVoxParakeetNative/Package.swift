// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxParakeetNative",
    platforms: [.macOS(.v13), .iOS("18.0")],
    products: [.library(name: "KeyVoxParakeetNative", targets: ["KeyVoxParakeetNative"])],
    dependencies: [.package(path: "../KeyVoxParakeet")],
    targets: [
        .target(name: "CParakeet", linkerSettings: [
            .linkedLibrary("parakeet", .when(platforms: [.android, .linux]))
        ]),
        .target(name: "KeyVoxParakeetNative", dependencies: [
            "CParakeet", .product(name: "KeyVoxParakeet", package: "KeyVoxParakeet")
        ]),
        .testTarget(name: "KeyVoxParakeetNativeTests", dependencies: ["KeyVoxParakeetNative"])
    ]
)
