// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "foreach-inline-always",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "foreach-inline-always"
        )
    ]
)
