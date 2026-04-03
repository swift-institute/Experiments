// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "noncopyable-access-patterns",
    platforms: [.macOS(.v26)],
    targets: [
        // Internal library targets for V05 cross-module experiment
        .target(
            name: "StorageLib",
            path: "Sources/StorageLib",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .target(
            name: "BufferLib",
            dependencies: ["StorageLib"],
            path: "Sources/BufferLib",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),
        .target(
            name: "DataStructureLib",
            dependencies: ["BufferLib"],
            path: "Sources/DataStructureLib",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),

        // Main library target
        .target(
            name: "NoncopyableAccessPatterns",
            dependencies: ["DataStructureLib"],
            path: "Sources/NoncopyableAccessPatterns",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ]
)
