// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxLinguistics",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "KeyVoxLinguistics", targets: ["KeyVoxLinguistics"])],
    targets: [
        .target(
            name: "KeyVoxLinguistics",
            resources: [
                .copy("Resources/PERCEPTRON-LICENSE.txt"),
                .copy("Resources/capitalized_spellings.txt"),
                .copy("Resources/punctuation_name_phrases.txt"),
            ]
        ),
        .testTarget(name: "KeyVoxLinguisticsTests", dependencies: ["KeyVoxLinguistics"]),
    ]
)
