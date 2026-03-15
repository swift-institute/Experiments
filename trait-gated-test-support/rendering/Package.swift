// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "rendering",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Rendering", targets: ["Rendering"]),
        .library(name: "Rendering Test Support", targets: ["Rendering Test Support"]),
    ],
    traits: [
        .trait(name: "SnapshotTesting"),
    ],
    dependencies: [
        .package(path: "../test-primitives"),
    ],
    targets: [
        .target(name: "Rendering"),
        .target(
            name: "Rendering Test Support",
            dependencies: [
                "Rendering",
                .product(
                    name: "TestSnapshotPrimitives",
                    package: "test-primitives",
                    condition: .when(traits: ["SnapshotTesting"])
                ),
            ],
            path: "Tests/Support",
            swiftSettings: [
                .define("SNAPSHOT_TESTING", .when(traits: ["SnapshotTesting"])),
            ]
        ),
    ]
)
