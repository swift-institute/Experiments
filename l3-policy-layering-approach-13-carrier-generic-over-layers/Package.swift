// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "l3-policy-layering-approach-13-carrier-generic-over-layers",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-primitives/swift-tagged-primitives"),
        .package(path: "../../../swift-primitives/swift-carrier-primitives"),
    ],
    targets: [
        .target(name: "L1Defs"),
        .target(
            name: "L2Methods",
            dependencies: [
                "L1Defs",
                .product(name: "Carrier Primitives", package: "swift-carrier-primitives"),
            ]
        ),
        .target(
            name: "L3Policy",
            dependencies: [
                "L2Methods",
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Carrier Primitives", package: "swift-carrier-primitives"),
            ]
        ),
        .executableTarget(
            name: "l3-policy-layering-approach-13-carrier-generic-over-layers",
            dependencies: [
                "L3Policy",
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Carrier Primitives", package: "swift-carrier-primitives"),
            ]
        )
    ]
)
