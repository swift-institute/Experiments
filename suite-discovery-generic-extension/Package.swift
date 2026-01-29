// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "suite-discovery-generic-extension",
    platforms: [.macOS(.v26)],
    targets: [
        .testTarget(
            name: "suite-discovery-generic-extension"
        )
    ]
)
