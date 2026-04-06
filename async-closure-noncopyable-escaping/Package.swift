// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "async-closure-noncopyable-escaping",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "async-closure-noncopyable-escaping"
        )
    ]
)
