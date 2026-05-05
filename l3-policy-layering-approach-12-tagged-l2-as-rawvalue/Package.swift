// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "l3-policy-layering-approach-12-tagged-l2-as-rawvalue",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-tagged-primitives"),
    ],
    targets: [
        .target(name: "L1Defs"),
        .target(
            name: "L2Methods",
            dependencies: ["L1Defs"]
        ),
        .target(
            name: "L3Policy",
            dependencies: [
                "L2Methods",
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ]
        ),
        .executableTarget(
            name: "l3-policy-layering-approach-12-tagged-l2-as-rawvalue",
            dependencies: [
                "L3Policy",
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ]
        )
    ]
)
