// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "consuming-bitmap-transfer",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "consuming-bitmap-transfer",
            dependencies: ["Core"],
            path: "Sources/Main"
        ),
    ]
)
