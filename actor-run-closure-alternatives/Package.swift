// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "actor-run-closure-alternatives",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "actor-run-closure-alternatives",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .unsafeFlags(["-parse-as-library"]),
            ]
        )
    ]
)
