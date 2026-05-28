// MARK: - D-exe: drive .collect() on the @_rawLayout-backed conformer ACROSS a module boundary.
//
// Purpose: isolate the @_rawLayout-storage factor — the one structural factor the plain-array
// Region conformers (which did NOT crash) lack vs the crashing Buffer.Linear.Inline<8>. The
// @_rawLayout conformer (RawRegion, owning a real Storage.Inline) + its Sequenceable conformance
// live in D-real-buffer-linear-lib; this executable drives .collect() cross-module, forcing the
// consumer to resolve the GENERIC Memory.Cursor<RawRegion<Int,8>> Iterator associated-type
// witness at runtime (the demangle site).
//
// Hypothesis: the @_rawLayout conformer crashes Signal-6 (swift_getAssociatedTypeWitness
// demangle) where the plain-array conformers did not — isolating @_rawLayout as the trigger.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.4-dev (LLVM a3655ee8d8c4d74)
// Platform: macOS 26 (arm64)
// Result: PASSES (debug + release, both toolchains). Output: "...collect().count = 8". The
//   @_rawLayout-backed conformer (owning a real Storage.Inline) — including the dual
//   Iterable+Sequenceable @_implements + value-generic + cross-module configuration (the
//   HIGHEST-FIDELITY reconstruction of Buffer.Linear.Inline) — does NOT crash. Isolating the
//   @_rawLayout-storage factor does not reproduce the demangle. See EXPERIMENT.md verdict.
// Date: 2026-05-27

import D_real_buffer_linear_lib
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// (1) via the library helper (call site inside D-lib).
let viaHelper = collectRaw(fill: 7, as: RawRegion<Int, 8>.self)
print("D viaHelper: RawRegion<Int,8>(@_rawLayout).collect().count = \(viaHelper.count) (expect 8)")

// (2) directly in the CONSUMING module — RawRegion<Int, 8> (matching the crash's Inline<8>).
func driveDirect() -> [Int] {
    let region = RawRegion<Int, 8>(fill: 9)
    return region.collect()
}
let direct = driveDirect()
print("D direct: RawRegion<Int,8>(@_rawLayout).collect().count = \(direct.count) (expect 8)")
