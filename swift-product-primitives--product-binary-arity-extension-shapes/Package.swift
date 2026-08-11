// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "product-binary-arity-extension-shapes",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "product-binary-arity-extension-shapes",
            swiftSettings: []
        )
    ]
)
