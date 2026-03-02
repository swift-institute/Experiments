// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "conditional-escapable-container",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ConditionalEscapableContainer",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        )
    ]
)
