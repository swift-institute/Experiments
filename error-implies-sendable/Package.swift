// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "error-implies-sendable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "error-implies-sendable",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
