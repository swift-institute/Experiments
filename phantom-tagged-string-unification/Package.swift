// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "phantom-tagged-string-unification",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "phantom-tagged-string-unification",
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
