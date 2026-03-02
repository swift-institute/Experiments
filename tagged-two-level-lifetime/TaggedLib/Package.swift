// swift-tools-version: 6.2
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
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        ),
    ]
)
