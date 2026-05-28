// swift-tools-version: 6.3
import PackageDescription

// SE-503 suppressed-associated-types cross-version probe.
// Flag enabled on BOTH targets so the suppressed-associatedtype syntax is
// available on Swift 6.3 (prototype). On final-SE-503 toolchains the flag is
// expected to be a graduated no-op / deprecation — part of what this verifies.
let package = Package(
    name: "se503-cross-version",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "SE503Defs",
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
        .executableTarget(
            name: "se503-cross-version",
            dependencies: ["SE503Defs"],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
    ]
)
