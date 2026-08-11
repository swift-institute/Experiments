// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "witness-recording-against-properties",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../../swift-foundations/swift-witnesses"),
    ],
    targets: [
        .executableTarget(
            name: "witness-recording-against-properties",
            dependencies: [
                .product(name: "Witnesses", package: "swift-witnesses"),
            ]
        )
    ]
)
