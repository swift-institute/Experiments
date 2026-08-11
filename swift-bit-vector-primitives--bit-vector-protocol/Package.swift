// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "bit-vector-protocol",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "bit-vector-protocol"
        )
    ]
)
