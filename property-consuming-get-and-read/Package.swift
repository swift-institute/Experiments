// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "property-consuming-get-and-read",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "property-consuming-get-and-read"
        )
    ]
)
