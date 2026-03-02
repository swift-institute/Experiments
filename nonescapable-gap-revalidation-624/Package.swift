// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonescapable-gap-revalidation-624",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "NonescapableGapRevalidation624",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
