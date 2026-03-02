// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "callback-isolated-prototype",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "callback-isolated-prototype"
        )
    ]
)
