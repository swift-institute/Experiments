// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "inline-subscript-performance",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-subscript-performance",
            swiftSettings: [
                .unsafeFlags(["-O", "-whole-module-optimization"], .when(configuration: .release))
            ]
        )
    ]
)
