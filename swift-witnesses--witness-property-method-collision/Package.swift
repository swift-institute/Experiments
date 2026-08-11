// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "witness-property-method-collision",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),   // swift-witnesses for V6 macro test
    ],
    targets: [
        .executableTarget(
            name: "witness-property-method-collision",
            dependencies: [
                .product(name: "Witnesses", package: "swift-witnesses"),
            ]
        )
    ]
)
