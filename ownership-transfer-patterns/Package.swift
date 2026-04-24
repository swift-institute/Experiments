// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ownership-transfer-patterns",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "OwnershipTransferPatterns",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
