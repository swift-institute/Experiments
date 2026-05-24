// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "storage-protocol-specialization",
    platforms: [.macOS(.v26)],
    targets: [
        // Module A — the "buffer-linear" package: capability protocol, two concrete
        // storages, the generic Layer-2 core, and a concrete non-@inlinable leaf.
        .target(
            name: "StorageCore",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes")
            ]
        ),
        // Module B — a downstream consumer in a SEPARATE module ([EXP-017] cross-module).
        .executableTarget(
            name: "consumer",
            dependencies: ["StorageCore"]
        ),
    ]
)
