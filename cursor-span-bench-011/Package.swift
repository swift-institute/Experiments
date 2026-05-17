// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "cursor-span-bench-011",
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
        .package(path: "../../../swift-primitives/swift-affine-primitives"),
        .package(path: "../../../swift-primitives/swift-index-primitives"),
        .package(path: "../../../swift-primitives/swift-byte-primitives"),
        .package(path: "../../../swift-primitives/swift-text-primitives"),
        .package(path: "../../../swift-primitives/swift-binary-parser-primitives"),
        .package(path: "../../../swift-primitives/swift-lexer-primitives"),
    ],
    targets: [
        .target(
            name: "Cursor Span Bench Subject",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Byte Primitives", package: "swift-byte-primitives"),
                .product(name: "Text Primitives", package: "swift-text-primitives"),
            ]
        ),
        .testTarget(
            name: "Cursor Span Bench Tests",
            dependencies: [
                "Cursor Span Bench Subject",
                .product(name: "Binary Input View Primitives", package: "swift-binary-parser-primitives"),
                .product(name: "Lexer Primitives", package: "swift-lexer-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
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
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
