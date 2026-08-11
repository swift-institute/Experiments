// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "parser-protocol-self-noncopyable-witness-tables",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-input-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
    ],
    targets: [
        // Module A: defines a Parser-shape protocol with Self: ~Copyable
        // and minimal conformers (a leaf Fail-shape, a composed Map-shape).
        // Bare module — no upstream deps to control metadata complexity.
        .target(
            name: "ProtocolModule"
        ),
        // V1–V4 consumer: cross-module instantiation with LOCAL concrete Input.
        .executableTarget(
            name: "parser-protocol-self-noncopyable-witness-tables",
            dependencies: [
                "ProtocolModule",
            ]
        ),
        // V5 consumer: cross-module instantiation with EXTERNAL-PACKAGE concrete
        // Input (Input.Slice<Buffer<UInt8>.Linear>) — the metadata-complexity
        // pattern that triggered the original 2026-02-14 production crash per
        // `swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`.
        .executableTarget(
            name: "external-input-test",
            dependencies: [
                "ProtocolModule",
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
