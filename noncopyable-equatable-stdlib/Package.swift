// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-equatable-stdlib",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-equatable-stdlib"
        )
    ]
)
