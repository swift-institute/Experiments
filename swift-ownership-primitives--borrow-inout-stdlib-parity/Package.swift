// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "borrow-inout-stdlib-parity",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-ownership-primitives")
    ],
    targets: [
        .executableTarget(
            name: "borrow-inout-stdlib-parity",
            dependencies: [
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives")
            ]
        )
    ]
)
