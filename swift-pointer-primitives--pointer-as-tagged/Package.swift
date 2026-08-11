// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "pointer-as-tagged",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: "../../../swift-identity-primitives"),
        .package(path: "../../../swift-affine-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "pointer-as-tagged",
            dependencies: [
                .product(name: "Identity Primitives", package: "swift-identity-primitives"),
                .product(name: "Affine Primitives", package: "swift-affine-primitives"),
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
