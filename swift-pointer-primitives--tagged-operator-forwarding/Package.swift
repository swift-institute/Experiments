// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-operator-forwarding",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-pointer-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "tagged-operator-forwarding",
            dependencies: [
                .product(name: "Pointer Primitives", package: "swift-pointer-primitives"),
            ]
        )
    ]
)
