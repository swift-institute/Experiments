// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TestNumeric",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "TestNumeric",
            dependencies: ["NumericPrimitives"]
        ),
        .binaryTarget(
            name: "NumericPrimitives",
            path: "../NumericPrimitives.xcframework"
        )
    ]
)
