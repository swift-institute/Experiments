// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bridge-noncopyable-ownership",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "bridge-noncopyable-ownership"
        )
    ]
)
