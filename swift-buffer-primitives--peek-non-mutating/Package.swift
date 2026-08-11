// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "peek-non-mutating",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "peek-non-mutating")
    ]
)
