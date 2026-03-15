// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "zero-copy-event-pipeline-validation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "zero-copy-event-pipeline-validation"
        )
    ]
)
