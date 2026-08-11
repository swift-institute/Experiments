// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-close-ownership",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-close-ownership"
        )
    ]
)
