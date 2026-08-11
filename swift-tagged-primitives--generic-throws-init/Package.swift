// swift-tools-version: 6.3

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("SuppressedAssociatedTypes"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "generic-throws-init",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-carrier-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Definitions",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Carrier Primitives", package: "swift-carrier-primitives"),
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "generic-throws-init",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                "Definitions",
            ],
            swiftSettings: swiftSettings
        ),
    ]
)
