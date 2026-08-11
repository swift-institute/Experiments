// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "parallel-iteration-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "parallel-iteration-test"
        )
    ]
)
