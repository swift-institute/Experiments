// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "executor-preference-noncopyable",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-kernel"),
    ],
    targets: [
        .executableTarget(
            name: "executor-preference-noncopyable",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
