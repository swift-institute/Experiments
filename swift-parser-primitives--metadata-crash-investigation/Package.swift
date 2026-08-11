// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "metadata-crash-investigation",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(path: "../../../swift-parser-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "metadata-crash-investigation",
            dependencies: [
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
