// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "spill-building-block",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "spill-building-block"
        )
    ]
)
