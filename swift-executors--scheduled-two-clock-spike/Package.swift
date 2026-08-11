// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "scheduled-two-clock-spike",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "scheduled-two-clock-spike")
    ]
)
