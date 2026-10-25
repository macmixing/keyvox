// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxKeyboardThemes",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxKeyboardThemes",
            targets: ["KeyVoxKeyboardThemes"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxKeyboardThemes",
            path: "Sources/KeyVoxKeyboardThemes"
        ),
        .testTarget(
            name: "KeyVoxKeyboardThemesTests",
            dependencies: ["KeyVoxKeyboardThemes"],
            path: "Tests/KeyVoxKeyboardThemesTests"
        ),
    ]
)
