// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "optional-take-sending-region-isolation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "optional-take-sending-region-isolation"
        )
    ]
)
