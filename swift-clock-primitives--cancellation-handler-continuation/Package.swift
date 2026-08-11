// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "cancellation-handler-continuation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "cancellation-handler-continuation"
        )
    ]
)
