// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "symbol-graph-conformance-oracle",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "symbol-graph-conformance-oracle",
            dependencies: [
                .product(name: "JSON", package: "swift-json")
            ]
        )
    ]
)
