// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dual-defunctionalize-composition",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "dual-defunctionalize-composition")
    ]
)
