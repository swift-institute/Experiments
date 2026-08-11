// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "consuming-method-patterns",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "ConsumingMethodPatterns",
            targets: ["ConsumingMethodPatterns"]
        ),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "ConsumingMethodPatterns",
            dependencies: [
                .product(name: "Either Primitives", package: "swift-either-primitives"),
            ]
        ),
        .executableTarget(
            name: "consuming-method-patterns",
            dependencies: [
                "ConsumingMethodPatterns",
                .product(name: "Either Primitives", package: "swift-either-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]
}
