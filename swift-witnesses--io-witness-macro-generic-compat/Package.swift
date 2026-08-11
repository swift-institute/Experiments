// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "io-witness-macro-generic-compat",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../../swift-foundations/swift-witnesses"),
    ],
    targets: [
        .executableTarget(
            name: "io-witness-macro-generic-compat",
            dependencies: [
                .product(name: "Witnesses", package: "swift-witnesses"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
