// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "tagged-no-niche-protocols",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-carrier-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "tagged-no-niche-protocols",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Carrier Primitives Standard Library Integration", package: "swift-carrier-primitives"),
            ]
        ),
    ]
)
