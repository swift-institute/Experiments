// MARK: - Production Reality Check
// Purpose: Drive the EXACT production footgun repro against real Bit.Index
//          + real Tagged Primitives Test Support (blanket literal conformance).
//          Removes any doubt that minimal-repro skeleton differences mask the bug.
//
// Original footgun from cross-domain-init-overload-resolution-footgun.md:
//   for i in (0..<5).map(Bit.Index.init) {
//       #expect(bits[i] == true)   // CRASHED on Swift 6.2: i became 0,8,16,24,32
//   }
//
// Toolchain: Swift 6.3.1 (Xcode 26.4.1 default; swiftlang-6.3.1.1.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-04-21
//
// Result: CONFIRMED — on real production types + test-support blanket literal
//         conformance, (0..<5).map(Bit.Index.init) produces ["0","1","2","3","4"]
//         (the correct integerLiteral path), NOT the ×8 byte-to-bit path.
//
// Evidence (stdout):
//   === Production Reality Check: Bit.Index footgun repro ===
//     (0..<5).map(Bit.Index.init): ["0", "1", "2", "3", "4"]
//
// This confirms the minimal-repro finding from the parent experiment: the
// footgun is dormant in current production state because production Tagged
// does not conform to Strideable. It will become ACTIVE the moment Strideable
// is added (per Strideable Index Design.md DECISION).
//
// Status: safe now, latent-hazardous later.

public import Bit_Index_Primitives
public import Index_Primitives
public import Tagged_Primitives
public import Tagged_Primitives_Test_Support  // provides ExpressibleByIntegerLiteral

print("=== Production Reality Check: Bit.Index footgun repro ===")

let result: [Bit.Index] = (0..<5).map(Bit.Index.init)
let raw = result.map { "\($0)" }
print("  (0..<5).map(Bit.Index.init): \(raw)")
