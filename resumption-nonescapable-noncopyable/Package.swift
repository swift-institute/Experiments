// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "resumption-nonescapable-noncopyable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ResumptionNonescapableNoncopyable",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
