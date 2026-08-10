// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "mutablespan-get-only",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutablespan-get-only",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
