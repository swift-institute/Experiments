// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "copyable-wrapper-refcount-cost",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "copyable-wrapper-refcount-cost"
        )
    ]
)
