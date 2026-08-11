// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "growth-policy-typed-arithmetic",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "growth-policy-typed-arithmetic",
            dependencies: [
                .product(name: "Buffer Primitives Core", package: "swift-buffer-primitives"),
            ]
        )
    ]
)
