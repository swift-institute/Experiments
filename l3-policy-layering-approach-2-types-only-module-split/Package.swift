// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "l3-policy-layering-approach-2-types-only-module-split",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "L1Defs"),
        .target(name: "L2Types", dependencies: ["L1Defs"]),
        .target(name: "L2Methods", dependencies: ["L1Defs", "L2Types"]),
        .target(name: "L3Policy", dependencies: ["L1Defs", "L2Types", "L2Methods"]),
        .executableTarget(
            name: "l3-policy-layering-approach-2-types-only-module-split",
            dependencies: ["L1Defs", "L2Types", "L3Policy"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
