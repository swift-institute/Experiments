// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tag-preserving-protocol-abstraction",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tag-preserving-protocol-abstraction"
        )
    ]
)
