// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "victim-selection-benchmark",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "victim-selection-benchmark")
    ]
)
