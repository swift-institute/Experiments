// swift-tools-version: 6.3
// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-institute project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "range-property-typed-throws-iteration",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "RangeIterateAdapter",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        .target(
            name: "NegativeControl"
        ),
        .target(
            name: "ForEachVariant",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        .target(
            name: "MapVariant",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        .executableTarget(
            name: "range-property-typed-throws-iteration",
            dependencies: ["RangeIterateAdapter"]
        ),
        .executableTarget(
            name: "foreach-variant-test",
            dependencies: ["ForEachVariant"]
        ),
        .executableTarget(
            name: "map-variant-test",
            dependencies: ["MapVariant"]
        ),
        .executableTarget(
            name: "range-batch-smoke-test",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        .executableTarget(
            name: "optional-result-stdlib-probe",
            dependencies: []
        ),
        .executableTarget(
            name: "range-perf-bench",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
