// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "unsafe-bitcast-generic-thin-function-pointer",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "unsafe-bitcast-generic-thin-function-pointer"
        )
    ]
)
