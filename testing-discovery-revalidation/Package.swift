// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "testing-discovery-revalidation",
    platforms: [.macOS(.v26)],
    targets: [
        .testTarget(
            name: "testing-discovery-revalidation"
        )
    ]
)
