// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxPredictiveKeyboard",
    platforms: [
        .iOS("18.0"),
        .macOS("13.3"),
    ],
    products: [
        .library(
            name: "KeyVoxPredictiveKeyboard",
            targets: ["KeyVoxPredictiveKeyboard"]
        ),
        .library(
            name: "KeyVoxTypingLanguageCatalog",
            targets: ["KeyVoxTypingLanguageCatalog"]
        ),
        .library(
            name: "KeyVoxTypingSimulation",
            targets: ["KeyVoxTypingSimulation"]
        ),
    ],
    dependencies: [
        .package(path: "../KeyVoxLinguistics"),
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
            name: "KeyVoxTypingLanguageCatalog",
            path: "Sources/KeyVoxTypingLanguageCatalog"
        ),
        .target(
            name: "KeyVoxPredictiveKeyboard",
            dependencies: [
                "KeyVoxPredictiveNative",
                "KeyVoxTypingLanguageCatalog",
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
            ],
            path: "Sources/KeyVoxPredictiveKeyboard",
            resources: [.copy("PredictiveData")],
            cSettings: [
                // Accelerate's current BLAS interface, as Apple documents for Swift.
                .define("ACCELERATE_NEW_LAPACK"),
            ]
        ),
        .target(
            name: "KeyVoxTypingSimulation",
            dependencies: ["KeyVoxPredictiveKeyboard"],
            path: "Sources/KeyVoxTypingSimulation"
        ),
        .testTarget(
            name: "KeyVoxPredictiveKeyboardTests",
            dependencies: ["KeyVoxPredictiveKeyboard", "KeyVoxTypingLanguageCatalog", "KeyVoxTypingSimulation"],
            path: "Tests/KeyVoxPredictiveKeyboardTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
