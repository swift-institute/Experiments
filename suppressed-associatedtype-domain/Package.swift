// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "suppressed-associatedtype-domain",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "suppressed-associatedtype-domain",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
    ]
)
