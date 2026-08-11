// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-literal-footgun-6-3-revalidation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "tagged-literal-footgun-6-3-revalidation"
        )
    ]
)
