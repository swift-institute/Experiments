// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "runtime-noncopyable-shutdown",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "runtime-noncopyable-shutdown"
        )
    ]
)
