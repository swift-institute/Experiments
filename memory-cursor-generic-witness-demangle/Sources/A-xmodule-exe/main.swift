// MARK: - A-xmodule-exe: drive .collect() on the GENERIC conformer ACROSS a module boundary.
//
// Purpose: reproduce the production Signal-6 crash
//   "failed to demangle witness for associated type 'Iterator' in conformance '…: Sequenceable'
//    → swift_getAssociatedTypeWitnessSlowImpl → collect()"
//   The conformer (Region<Element>: Sequenceable) lives in AConformerLib; this executable
//   imports it and drives .collect() — so the associated-type-witness for the generic
//   Iterator (Memory.Cursor<Region<Element>>) must be resolved across the module boundary.
//   This is the cross-module dimension the single-module target A did not exercise
//   ([EXP-017] / [ISSUE-013] module-isolation variable).
//
// Hypothesis: the cross-module GENERIC drive crashes Signal-6 (single-module A passed
//   debug + release).
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.4-dev (LLVM a3655ee8d8c4d74)
// Platform: macOS 26 (arm64)
// Result: ALL VARIANTS PASS (debug + release, both toolchains). The cross-module GENERIC
//   conformer — including value-generic, dual Iterable+Sequenceable @_implements, and the
//   cross-module bridge-default-witness path — does NOT crash. Combined with target D
//   (@_rawLayout) also passing, NO synthetic reconstruction of Buffer.Linear.Inline<8>:
//   Sequenceable reproduces the verified Signal-6 demangle. See EXPERIMENT.md verdict.
// Date: 2026-05-27

import AConformerLib
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// Drive .collect() from a GENERIC function in the CONSUMING module — forces the consumer
// to resolve the Iterator associated-type witness for Region<Element> at runtime.
func driveGeneric<Element: Copyable & Escapable>(_ values: [Element]) -> [Element] {
    let region = Region(values)
    return region.collect()
}

let out = driveGeneric([10, 20, 30])
print("A-xmodule: collect() = \(out) (expect [10, 20, 30])")

// Value-generic conformer (one factor closer to Buffer.Linear.Inline<let capacity:Int>).
// Drive .collect() across the module boundary on a VALUE-generic type, in two sub-cases:
//   (1) capacity fixed at the call site (RegionVG<Int, 8>) — like the crash's Inline<8>;
//   (2) capacity itself generic, reached through a generic function whose `capacity` flows
//       from a value-generic caller.
func driveValueGeneric<Element: Copyable & Escapable, let capacity: Int>(
    _ values: [Element], cap _: RegionVG<Element, capacity>.Type
) -> [Element] {
    let region = RegionVG<Element, capacity>(values)
    return region.collect()
}

let outVGConcrete = RegionVG<Int, 8>([10, 20, 30]).collect()
print("A-xmodule VG (capacity fixed=8): collect() = \(outVGConcrete) (expect [10, 20, 30])")

let outVGGeneric = driveValueGeneric([10, 20, 30], cap: RegionVG<Int, 8>.self)
print("A-xmodule VG (capacity generic, =8): collect() = \(outVGGeneric) (expect [10, 20, 30])")

// DUAL Iterable + Sequenceable conformer — the EXACT crashing production shape. Drive the
// Sequenceable .collect() across the module boundary on the GENERIC dual conformer. This is
// the highest-fidelity reconstruction of the verified crash.
func driveDual<Element: Copyable & Escapable>(_ values: [Element]) -> [Element] {
    let region = RegionDual(values)
    return region.collect()
}

let outDual = driveDual([10, 20, 30])
print("A-xmodule DUAL (Iterable+Sequenceable @_implements): collect() = \(outDual) (expect [10, 20, 30])")

// BRIDGE-DEFAULT conformer — relies on the cross-module bridge default makeIterator()
// (no explicit one), exactly like the crashing Buffer.Linear.Inline. This is the one
// witness-emission path the explicit-makeIterator variants bypass.
func driveBridgeDefault<Element: Copyable & Escapable>(_ values: [Element]) -> [Element] {
    let region = RegionBD(values)
    return region.collect()
}

let outBD = driveBridgeDefault([10, 20, 30])
print("A-xmodule BRIDGE-DEFAULT (cross-module default witness): collect() = \(outBD) (expect [10, 20, 30])")
