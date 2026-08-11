// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ternary-operator-inference",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ternary-operator-inference",
            dependencies: [
                .product(name: "Logic Ternary Primitives", package: "swift-logic-primitives"),
            ]
        )
    ]
)
