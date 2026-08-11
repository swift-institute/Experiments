// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "io-witness-domain-generic-substrate",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "io-witness-domain-generic-substrate"
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
