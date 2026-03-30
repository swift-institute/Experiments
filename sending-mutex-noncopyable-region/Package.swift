// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sending-mutex-noncopyable-region",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sending-mutex-noncopyable-region"
        )
    ]
)
