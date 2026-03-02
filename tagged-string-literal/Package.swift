// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-string-literal",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-string-literal",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        )
    ]
)
