// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "result-builder-perf",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-array-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-stack-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-queue-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-set-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-bitset-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "result-builder-perf",
            dependencies: [
                .product(name: "Array Primitives", package: "swift-array-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Stack Primitives", package: "swift-stack-primitives"),
                .product(name: "Queue Primitives", package: "swift-queue-primitives"),
                .product(name: "Heap Primitives", package: "swift-heap-primitives"),
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Bitset Primitives", package: "swift-bitset-primitives"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        )
    ]
)
