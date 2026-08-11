// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "tagged-viewable-char-crossmodule",
    platforms: [.macOS(.v26)],
    targets: [
        // Module 1: Tagged + Viewable (mirrors identity-primitives)
        .target(
            name: "Core",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        // Module 2: String + String.View + String.Char + Tagged extension (mirrors string-primitives)
        .target(
            name: "StringDomain",
            dependencies: ["Core"]
        ),
        // Module 3: Path + Path.Char + Tagged extension (mirrors path-primitives)
        // NOTE: Removed StringDomain dependency for bisect
        .target(
            name: "PathDomain",
            dependencies: ["Core"]
        ),
        // Module 4: Kernel.Path = Tagged<Kernel, Path> (mirrors kernel-primitives)
        .target(
            name: "KernelDomain",
            dependencies: ["Core", "StringDomain", "PathDomain"]
        ),
        // Module 5: Consumer that tests Char resolution (mirrors iso-9945)
        .executableTarget(
            name: "tagged-viewable-char-crossmodule",
            dependencies: ["Core", "KernelDomain", "PathDomain", "StringDomain"],
            path: "Sources/App"
        ),
    ]
)

for target in package.targets {
    var ecosystem: [SwiftSetting] = [
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
    ecosystem += [
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InternalImportsByDefault"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
