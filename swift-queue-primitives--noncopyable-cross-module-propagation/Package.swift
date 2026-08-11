// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "noncopyable-cross-module-propagation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-list-primitives.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-cross-module-propagation",
            dependencies: [
                .product(name: "List Primitives", package: "swift-list-primitives")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
