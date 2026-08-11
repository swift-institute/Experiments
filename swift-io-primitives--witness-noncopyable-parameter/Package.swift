// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "witness-noncopyable-parameter",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "witness-noncopyable-parameter"
        )
    ]
)
