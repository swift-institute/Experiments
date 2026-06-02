// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dependency-scope-writeback",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-dependency-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "dependency-scope-writeback",
            dependencies: [
                .product(name: "Dependency Primitives", package: "swift-dependency-primitives"),
            ]
        )
    ]
)
