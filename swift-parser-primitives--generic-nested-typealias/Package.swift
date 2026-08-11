// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "generic-nested-typealias",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "generic-nested-typealias"
        )
    ]
)
