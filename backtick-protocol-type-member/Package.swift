// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "backtick-protocol-type-member",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "backtick-protocol-type-member"
        )
    ]
)
