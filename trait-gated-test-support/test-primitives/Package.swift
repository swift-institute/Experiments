// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "test-primitives",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TestSnapshotPrimitives", targets: ["TestSnapshotPrimitives"]),
    ],
    targets: [
        .target(name: "TestSnapshotPrimitives"),
    ]
)
