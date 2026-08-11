// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "chase-lev-deque-spike",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "chase-lev-deque-spike",
            dependencies: [
                .product(name: "Memory Inline Primitives", package: "swift-memory-primitives")
            ]
        )
    ]
)
