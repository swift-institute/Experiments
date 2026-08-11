// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "owned-consuming-get-on-protocol-extension",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "owned-consuming-get-on-protocol-extension"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    let settings: [SwiftSetting] = [
        .enableExperimentalFeature("UnderscoreOwned"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
