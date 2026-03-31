// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "v3-with-deps",
    platforms: [.macOS(.v26), .iOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "v3-with-deps",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        )
    ]
)
