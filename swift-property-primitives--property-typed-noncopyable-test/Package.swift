// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "property-typed-noncopyable-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Test",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
