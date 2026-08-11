// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "syntax-showcase",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "Showcase",
            path: "Sources/Showcase"
        ),
        .testTarget(
            name: "Showcase Tests",
            dependencies: [
                "Showcase",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
