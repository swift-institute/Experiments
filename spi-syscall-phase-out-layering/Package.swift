// swift-tools-version: 6.3
import PackageDescription

// MARK: - SPI Syscall Phase-Out Access-Control Variant Experiment
// Purpose: Empirically determine which access-control mechanism supports
// legitimate raw-FFI use cases without exposing raw shape at any L2 public surface.
//
// 6 variants × 3 targets each = 18 targets:
//   V1: status quo @_spi(Syscall) raw companion at L2
//   V2: private FFI inside L2 wrapper; typed-only public/SPI
//   V3: internal raw at L2; sibling target accesses via @testable import
//   V4: package raw at L2; same-SPM-package targets see it
//   V5: typed-only L2; consumer writes its own raw shim
//   V6: typed-only everywhere — feasibility baseline (no raw at any layer)

let package = Package(
    name: "spi-syscall-phase-out-layering",
    platforms: [.macOS(.v26)],
    targets: [
        // V1 — status quo @_spi(Syscall)
        .target(name: "V1_L2"),
        .target(name: "V1_L3", dependencies: ["V1_L2"]),
        .executableTarget(name: "V1_Consumer", dependencies: ["V1_L2", "V1_L3"]),

        // V2 — private FFI inside L2 wrapper; typed-only public surface
        .target(name: "V2_L2"),
        .target(name: "V2_L3", dependencies: ["V2_L2"]),
        .executableTarget(name: "V2_Consumer", dependencies: ["V2_L2", "V2_L3"]),

        // V3 — internal raw at L2; sibling target accesses via @testable import
        // V3_L2 has -enable-testing so V3_Consumer can @testable import in any mode
        .target(
            name: "V3_L2",
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        ),
        .target(name: "V3_L3", dependencies: ["V3_L2"]),
        .executableTarget(
            name: "V3_Consumer",
            dependencies: ["V3_L2", "V3_L3"],
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        ),

        // V4 — package raw at L2; same-SPM-package targets see it
        .target(name: "V4_L2"),
        .target(name: "V4_L3", dependencies: ["V4_L2"]),
        .executableTarget(name: "V4_Consumer", dependencies: ["V4_L2", "V4_L3"]),

        // V5 — typed-only L2; consumer writes its own raw shim
        .target(name: "V5_L2"),
        .target(name: "V5_L3", dependencies: ["V5_L2"]),
        .executableTarget(name: "V5_Consumer", dependencies: ["V5_L2", "V5_L3"]),

        // V6 — typed-only everywhere; feasibility baseline
        .target(name: "V6_L2"),
        .target(name: "V6_L3", dependencies: ["V6_L2"]),
        .executableTarget(name: "V6_Consumer", dependencies: ["V6_L2", "V6_L3"]),
    ]
)
