// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .strictMemorySafety(),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("SuppressedAssociatedTypes"),
    .enableExperimentalFeature("RawLayout"),
]

let package = Package(
    name: "iterator-slab-cross-module",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "iterator-slab-cross-module",
            dependencies: [
                .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "TestableImportTests",
            dependencies: [
                .product(name: "Dictionary Primitives", package: "swift-dictionary-primitives"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
