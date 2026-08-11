// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "operator-forwarding",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "operator-forwarding")
    ],
    swiftLanguageModes: [.v6]
)
