// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iterator-struct-storage",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "iterator-struct-storage",
            dependencies: [
                .product(name: "Bit Vector Primitives", package: "swift-bit-vector-primitives"),
            ],
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportsByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
