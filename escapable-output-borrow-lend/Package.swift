// swift-tools-version: 6.3
import PackageDescription

let lifetimeSettings: [SwiftSetting] = [
    .enableExperimentalFeature("LifetimeDependence"),
    .enableExperimentalFeature("Lifetimes"),
    .enableExperimentalFeature("SuppressedAssociatedTypes"),
]

let package = Package(
    name: "escapable-output-borrow-lend",
    platforms: [.macOS(.v26)],
    targets: [
        // Cross-module library ([EXP-017]): the achievable-today vending types
        // live here and are consumed across the module boundary by the executable.
        .target(
            name: "BorrowLendKit",
            swiftSettings: lifetimeSettings
        ),
        .executableTarget(
            name: "escapable-output-borrow-lend",
            dependencies: ["BorrowLendKit"],
            swiftSettings: lifetimeSettings
        ),
    ]
)
