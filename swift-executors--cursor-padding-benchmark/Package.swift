// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "cursor-padding-benchmark",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-cpu-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "cursor-padding-benchmark",
            dependencies: [
                .product(name: "CPU Primitives", package: "swift-cpu-primitives"),
            ]
        )
    ]
)
