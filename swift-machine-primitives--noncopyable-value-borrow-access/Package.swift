// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-value-borrow-access",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "noncopyable-value-borrow-access",
            path: "Sources"
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        // NonisolatedNonsendingByDefault omitted — not relevant to this experiment
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
