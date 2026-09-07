// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxSpeechHarness",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../Packages/KeyVoxCore"),
        .package(path: "../../Packages/KeyVoxLinguistics"),
        .package(path: "../../Packages/KeyVoxWhisper"),
        .package(path: "../../Packages/KeyVoxVoiceActivity"),
        .package(path: "../../Packages/KeyVoxParakeetNative"),
    ],
    targets: [
        .executableTarget(
            name: "KeyVoxSpeechHarness",
            dependencies: [
                .product(name: "KeyVoxCore", package: "KeyVoxCore"),
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
                .product(name: "KeyVoxWhisper", package: "KeyVoxWhisper"),
                .product(name: "KeyVoxVoiceActivity", package: "KeyVoxVoiceActivity"),
                .product(name: "KeyVoxParakeetNative", package: "KeyVoxParakeetNative"),
            ],
            linkerSettings: [
                .linkedLibrary("ssl", .when(platforms: [.android])),
                .linkedLibrary("crypto", .when(platforms: [.android])),
                .linkedLibrary("z", .when(platforms: [.android])),
            ]
        ),
    ]
)
