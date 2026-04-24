// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "sendable-noncopyable-conditional-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sendable-noncopyable-conditional-conformance",
            swiftSettings: [
                .strictMemorySafety(),
            ]
        )
    ]
)
