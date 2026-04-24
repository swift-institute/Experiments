// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "noncopyable-driver-witness",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-driver-witness",
            swiftSettings: [
                .strictMemorySafety(),
            ]
        )
    ]
)
