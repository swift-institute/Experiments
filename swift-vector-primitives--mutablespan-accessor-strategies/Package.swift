// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "mutablespan-accessor-strategies",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutablespan-accessor-strategies",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
