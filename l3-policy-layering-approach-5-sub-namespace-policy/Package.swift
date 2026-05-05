// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "l3-policy-layering-approach-5-sub-namespace-policy",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "L1Defs"),
        .target(name: "L2Methods", dependencies: ["L1Defs"]),
        .target(name: "L3Policy", dependencies: ["L1Defs", "L2Methods"]),
        .executableTarget(
            name: "l3-policy-layering-approach-5-sub-namespace-policy",
            dependencies: ["L1Defs", "L2Methods", "L3Policy"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
