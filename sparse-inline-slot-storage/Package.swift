// swift-tools-version: 6.2
import PackageDescription

// Experiment: a uniform, conditionally-Copyable, generic sparse-inline buffer via
// `InlineArray<N, Slot<Element>>` (self-cleaning slot-enum, NO custom deinit) — the
// candidate replacement for the @_rawLayout `.Inline`/`.Small` forced-concrete leaves.
// macOS 26 floor encodes the InlineArray (SE-0453) DYNAMIC-stdlib availability finding (R4).
// Embedded deployment is verified separately via ./embedded-check.sh (static stdlib, no OS floor).
let package = Package(
    name: "sparse-inline-slot-storage",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "SlotStorage"),
        .executableTarget(name: "Demo", dependencies: ["SlotStorage"]),
    ]
)
