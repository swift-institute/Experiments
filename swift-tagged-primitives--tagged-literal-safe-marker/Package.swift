// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-literal-safe-marker",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-literal-safe-marker"
        )
    ]
)
