// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "foreign-recycle-channel",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(path: "../../../swift-async-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "foreign-recycle-channel",
            dependencies: [
                .product(name: "Memory Foreign Primitives", package: "swift-memory-foreign-primitives"),
                .product(name: "Memory Foreign Primitives Test Support", package: "swift-memory-foreign-primitives"),
                .product(name: "Async Primitives Core", package: "swift-async-primitives"),
                .product(name: "Async Channel Primitives", package: "swift-async-primitives"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        )
    ]
)
