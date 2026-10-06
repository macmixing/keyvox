// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxPredictiveKeyboard",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxPredictiveKeyboard",
            targets: ["KeyVoxPredictiveKeyboard"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxPredictiveNative",
            path: "Sources/KeyVoxPredictiveNative",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
                .headerSearchPath("latinime"),
                .define("KEYVOX_LATINIME_PORT"),
                // The bundled LatinIME sources narrow sizes to int and use variable-length
                // arrays throughout, as upstream does.
                .unsafeFlags(["-Wno-shorten-64-to-32", "-Wno-vla-cxx-extension"]),
            ]
        ),
        .target(
            name: "KeyVoxPredictiveKeyboard",
            dependencies: ["KeyVoxPredictiveNative"],
            path: "Sources/KeyVoxPredictiveKeyboard",
            resources: [.copy("PredictiveData")]
        ),
        .testTarget(
            name: "KeyVoxPredictiveKeyboardTests",
            dependencies: ["KeyVoxPredictiveKeyboard"],
            path: "Tests/KeyVoxPredictiveKeyboardTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
