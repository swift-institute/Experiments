// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ordinal-finite-tagged",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "ordinal-finite-tagged",
            dependencies: [
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
