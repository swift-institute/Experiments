// swift-tools-version: 6.3
import PackageDescription

// Spike for swift-institute/Research/memory-contiguous-iteration-bridge.md (§1 revision + OQ-1).
// Two independent probes, built separately:
//   oq1-chunk-floor   — does Iterator.Chunk require Element: BitwiseCopyable? (OQ-1)
//   oq2-owned-cursor  — does an Escapable owned cursor conforming Iterator.`Protocol`,
//                       vended from Sequenceable's `@_lifetime(copy self) consuming
//                       func makeIterator()`, typecheck? (OQ-2 / revised §1 shape)
// No edits to live packages; clean build; first clean signal is the result.

let settings: [SwiftSetting] = [
    .enableExperimentalFeature("Lifetimes"),
]

let package = Package(
    name: "memory-contiguous-sequenceable-bridge-shape",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "oq1-chunk-floor",
            dependencies: [
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "oq2-owned-cursor",
            dependencies: [
                .product(name: "Sequence Protocol Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterator Primitives", package: "swift-iterator-primitives"),
            ],
            swiftSettings: settings
        ),
    ]
)
