// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-throwing-init",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-throwing-init"
        )
    ]
)
