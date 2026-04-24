// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-actor-driver-ownership",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-actor-driver-ownership"
        )
    ]
)
