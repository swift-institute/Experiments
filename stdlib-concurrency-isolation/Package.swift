// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "stdlib-concurrency-isolation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "stdlib-concurrency-isolation"
        )
    ]
)
