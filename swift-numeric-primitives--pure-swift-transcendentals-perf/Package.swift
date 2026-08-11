// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "pure-swift-transcendentals-perf",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "pure-swift-transcendentals-perf"
        )
    ]
)
