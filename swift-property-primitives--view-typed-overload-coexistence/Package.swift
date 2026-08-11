// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "view-typed-overload-coexistence",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "view-typed-overload-coexistence",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
