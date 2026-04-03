// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-operation-closure-pipeline",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-operation-closure-pipeline"
        )
    ]
)
