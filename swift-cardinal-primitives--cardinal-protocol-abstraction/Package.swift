// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cardinal-protocol-abstraction",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "cardinal-protocol-abstraction"
        )
    ]
)
