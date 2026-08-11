// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "pointer-memory-address",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../../../swift-identity-primitives"),
        .package(path: "../../../swift-index-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "pointer-memory-address",
            dependencies: [
                .product(name: "Identity Primitives", package: "swift-identity-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
