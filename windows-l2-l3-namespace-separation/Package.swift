// swift-tools-version: 6.3
import PackageDescription

// MARK: - Windows L2/L3 Namespace Separation Experiment
//
// Tests 5 candidate naming patterns for the Windows-side L2/L3 platform stack.
// Each variant is a 3-target chain (L2 raw → L3 policy → Consumer) plus a
// shared FakeHandle utility used to simulate a Win32 HANDLE on macOS.
//
// V1 — status quo:    Windows.Kernel.X       at L2 + Windows.Kernel.X at L3
// V2 — sub-namespace: Windows.ABI.Kernel.X   at L2 + Windows.Kernel.X at L3
// V3 — twin roots:    Win32.Kernel.X         at L2 + Windows.Kernel.X at L3
// V4 — org-prefix:    Microsoft.Kernel.X     at L2 + Windows.Kernel.X at L3
// V5 — literal-spec:  WinSDK.Kernel.X        at L2 + Windows.Kernel.X at L3

let package = Package(
    name: "windows-l2-l3-namespace-separation",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "V1_Consumer", targets: ["V1_Consumer"]),
        .executable(name: "V2_Consumer", targets: ["V2_Consumer"]),
        .executable(name: "V3_Consumer", targets: ["V3_Consumer"]),
        .executable(name: "V4_Consumer", targets: ["V4_Consumer"]),
        .executable(name: "V5_Consumer", targets: ["V5_Consumer"]),
    ],
    targets: [
        // Shared utility (1 target).
        .target(name: "SharedHandle"),

        // V1 — status quo (3 targets).
        .target(name: "V1_L2", dependencies: ["SharedHandle"]),
        .target(name: "V1_L3", dependencies: ["V1_L2", "SharedHandle"]),
        .executableTarget(name: "V1_Consumer", dependencies: ["V1_L3", "SharedHandle"]),

        // V2 — sub-namespace (3 targets).
        .target(name: "V2_L2", dependencies: ["SharedHandle"]),
        .target(name: "V2_L3", dependencies: ["V2_L2", "SharedHandle"]),
        .executableTarget(name: "V2_Consumer", dependencies: ["V2_L3", "SharedHandle"]),

        // V3 — twin roots (3 targets).
        .target(name: "V3_L2", dependencies: ["SharedHandle"]),
        .target(name: "V3_L3", dependencies: ["V3_L2", "SharedHandle"]),
        .executableTarget(name: "V3_Consumer", dependencies: ["V3_L3", "SharedHandle"]),

        // V4 — org-prefix (3 targets).
        .target(name: "V4_L2", dependencies: ["SharedHandle"]),
        .target(name: "V4_L3", dependencies: ["V4_L2", "SharedHandle"]),
        .executableTarget(name: "V4_Consumer", dependencies: ["V4_L3", "SharedHandle"]),

        // V5 — literal-spec (3 targets).
        .target(name: "V5_L2", dependencies: ["SharedHandle"]),
        .target(name: "V5_L3", dependencies: ["V5_L2", "SharedHandle"]),
        .executableTarget(name: "V5_Consumer", dependencies: ["V5_L3", "SharedHandle"]),
    ]
)
