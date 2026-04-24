// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "witness-driver-composition",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "witness-driver-composition"
        )
    ]
)
