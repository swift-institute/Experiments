// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nested-noncopyable-test",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "nested-noncopyable-test")
    ]
)
