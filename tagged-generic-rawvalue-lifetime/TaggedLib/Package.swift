// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "TaggedLib",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "TaggedLib", targets: ["TaggedLib"]),
    ],
    targets: [
        .target(
            name: "TaggedLib",
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        ),
    ]
)
