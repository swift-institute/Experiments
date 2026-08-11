// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "priority-override-spike",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "priority-override-spike")
    ]
)
