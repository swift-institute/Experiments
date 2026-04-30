// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestConsumer",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "TestConsumer",
            dependencies: ["IdentityPrimitives"]
        ),
        .binaryTarget(
            name: "IdentityPrimitives",
            path: "../IdentityPrimitives.xcframework"
        )
    ]
)
