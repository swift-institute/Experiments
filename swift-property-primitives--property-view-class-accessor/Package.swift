// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "property-view-class-accessor",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-property-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "property-view-class-accessor",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
