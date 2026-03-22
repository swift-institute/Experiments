// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-closure-type-constraints",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonsending-closure-type-constraints"
        )
    ]
)
