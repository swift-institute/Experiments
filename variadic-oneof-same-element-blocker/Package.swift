// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "variadic-oneof-same-element-blocker",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "variadic-oneof-same-element-blocker",
            swiftSettings: []
        )
    ]
)
