// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "nested-in-generic-extension-target-boundary",
    platforms: [.macOS(.v26)],
    targets: [
        // Mirrors swift-ownership-primitives layout:
        //   Ownership Namespace → Ownership Primitives Core → Ownership Transfer Primitives
        //     → Ownership Primitives (umbrella) → Ownership Primitives Tests
        .target(name: "OuterNamespace"),
        .target(name: "OuterCore", dependencies: ["OuterNamespace"]),
        .target(name: "VariantPrimitives", dependencies: ["OuterCore"]),
        .target(name: "Umbrella", dependencies: [
            "OuterNamespace", "OuterCore", "VariantPrimitives",
        ]),
        .executableTarget(
            name: "nested-in-generic-extension-target-boundary",
            dependencies: ["Umbrella"]
        )
    ]
)
