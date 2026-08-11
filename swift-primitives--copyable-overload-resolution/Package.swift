// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "copyable-overload-resolution",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "copyable-overload-resolution"
        )
    ]
)
