// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "cursor-shape-a-feasibility",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-tagged-primitives"),
        .package(path: "../../../swift-primitives/swift-ordinal-primitives"),
        .package(path: "../../../swift-primitives/swift-cardinal-primitives"),
    ],
    targets: [
        .target(
            name: "CursorShapeASubject",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
            ]
        ),
        // Cross-module consumer per [EXP-017]
        .executableTarget(
            name: "CursorShapeAConsumer",
            dependencies: ["CursorShapeASubject"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
}
