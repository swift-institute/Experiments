// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "adt-over-buffer-seam",
    platforms: [.macOS(.v26)],
    targets: [
        // Library target — the experimental API (V1 sketch + V2 alternative).
        .target(
            name: "Seam",
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
        // Consumer target — exercises the API ACROSS A MODULE BOUNDARY ([EXP-017]).
        .executableTarget(
            name: "client",
            dependencies: ["Seam"],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
    ]
)
