// swift-tools-version: 6.2

import PackageDescription

let commonSettings: [SwiftSetting] = [
    .enableExperimentalFeature("RawLayout"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableExperimentalFeature("Lifetimes"),
    .strictMemorySafety(),
]

let package = Package(
    name: "rawlayout-llvm-verifier-crash",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [
        // V01: Minimal @_rawLayout + deinit types, standalone
        .executableTarget(
            name: "V01-baseline",
            swiftSettings: [.enableExperimentalFeature("RawLayout")]
        ),

        // V02: Struct-body threshold — 1, 2, 3 types with real dependencies
        .executableTarget(
            name: "V02-struct-body-threshold",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: commonSettings
        ),

        // V03: Extension-file pattern — type via extension in separate file
        .executableTarget(
            name: "V03-extension-file",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: commonSettings
        ),

        // V04: Cross-module — types in separate module extending parent
        .target(
            name: "V04-cross-module-core",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: commonSettings
        ),
        .executableTarget(
            name: "V04-cross-module",
            dependencies: ["V04-cross-module-core"],
            swiftSettings: commonSettings
        ),

        // V05: Class-ref interaction — Storage.Contiguous<Memory.Heap> + @_rawLayout
        .executableTarget(
            name: "V05-class-ref-interaction",
            swiftSettings: [.enableExperimentalFeature("RawLayout")]
        ),

        // V06: Wrapper patterns — _Fields wrapper, single-field wrapper
        .executableTarget(
            name: "V06-wrapper-patterns",
            swiftSettings: [.enableExperimentalFeature("RawLayout")]
        ),

        // V07: ~Copyable elements in @_rawLayout
        .executableTarget(
            name: "V07-noncopyable-elements",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ],
            swiftSettings: [.enableExperimentalFeature("RawLayout")]
        ),

        // V08: Real Storage.Inline deinit from pre-compiled package
        .executableTarget(
            name: "V08-storage-inline-deinit",
            dependencies: [
                .product(name: "Storage Primitives", package: "swift-storage-primitives"),
            ],
            swiftSettings: commonSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
