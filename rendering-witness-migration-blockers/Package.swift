// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "rendering-witness-migration-blockers",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-property-primitives"),
    ],
    targets: [
        .target(
            name: "Variants",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            path: "Sources/Variants"
        ),
        .testTarget(
            name: "Blocker Tests",
            dependencies: ["Variants"],
            path: "Tests/Blocker Tests"
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]
}
