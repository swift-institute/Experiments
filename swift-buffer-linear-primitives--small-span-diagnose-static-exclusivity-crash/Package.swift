// swift-tools-version: 6.3
import PackageDescription

// Standalone experiment package (per [EXP-002b]): the parent
// swift-buffer-linear-primitives does NOT reference this as a target, so its
// `swift build` / `swift test` ignore it entirely.
let package = Package(
    name: "small-span-diagnose-static-exclusivity-crash",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "small-span-diagnose-static-exclusivity-crash",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes")
            ]
        )
    ]
)
