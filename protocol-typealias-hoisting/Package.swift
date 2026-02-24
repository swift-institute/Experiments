// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-typealias-hoisting",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "protocol-typealias-hoisting",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
