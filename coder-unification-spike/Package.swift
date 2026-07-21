// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "coder-unification-spike",
    platforms: [.macOS(.v26)],
    dependencies: [
        // B2 entry gate spike — canonical URL spellings; the global mirror table
        // (~/.swiftpm/configuration/mirrors.json) resolves these to the local
        // workspace checkouts. The experiment consumes, never edits, its deps.
        .package(url: "https://github.com/swift-primitives/swift-parser-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-serializer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-coder-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "coder-unification-spike",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
                .product(name: "Serializer Primitives", package: "swift-serializer-primitives"),
                .product(name: "Coder Primitives", package: "swift-coder-primitives"),
            ]
        ),
        .testTarget(
            name: "coder-unification-spikeTests",
            dependencies: ["coder-unification-spike"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
