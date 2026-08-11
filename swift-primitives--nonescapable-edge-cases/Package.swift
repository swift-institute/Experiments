// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonescapable-edge-cases",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "NonescapableEdgeCases",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("RawLayout"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .strictMemorySafety(),
            ]
        )
    ]
)
