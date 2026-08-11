// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "metadata-crash-bisection",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-array-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
    ],
    targets: [
        // Minimal module: only Parser.Protocol + Parser.Always (no retroactive conformances)
        .target(
            name: "MinimalParserModule",
            dependencies: [
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Array Primitives", package: "swift-array-primitives"),
            ]
        ),
        // Same as MinimalParserModule but WITHOUT ~Escapable on Input
        .target(
            name: "NoEscapableModule",
            dependencies: [
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Array Primitives", package: "swift-array-primitives"),
            ]
        ),
        // V1: Test with ~Escapable (minimal module)
        .executableTarget(
            name: "metadata-crash-bisection",
            dependencies: [
                "MinimalParserModule",
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        // V2: Test WITHOUT ~Escapable
        .executableTarget(
            name: "no-escapable-test",
            dependencies: [
                "NoEscapableModule",
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        // Bare module: no upstream deps, no ~Escapable, no Failure — absolute minimum
        .target(
            name: "BareModule"
        ),
        // V3: Test with bare module (client imports upstream types directly)
        .executableTarget(
            name: "bare-module-test",
            dependencies: [
                "BareModule",
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        // Plain generic struct, no protocol at all
        .target(
            name: "BoxModule"
        ),
        // V4: Cross-module generic Box<ByteInput, Int> — no protocol
        .executableTarget(
            name: "box-test",
            dependencies: [
                "BoxModule",
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        // V5: Decision tree isolation tests
        .executableTarget(
            name: "trivial-box-test",
            dependencies: [
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Array Primitives", package: "swift-array-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
