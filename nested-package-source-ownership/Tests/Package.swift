// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "testing",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .testTarget(
            name: "Extended Tests",
            dependencies: [
                .product(name: "Lib", package: "nested-package-source-ownership"),
            ],
            path: "Extended Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
