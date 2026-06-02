// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "binary-base-n-poc",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "BinaryBase",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .target(
            name: "BinaryBaseClosed",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .target(
            name: "BinaryBaseProperty",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .executableTarget(
            name: "binary-base-n-poc",
            dependencies: ["BinaryBase", "BinaryBaseClosed", "BinaryBaseProperty"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
