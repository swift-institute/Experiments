// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "static-stored-property-in-generic-type",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "static-stored-property-in-generic-type"
        )
    ]
)
