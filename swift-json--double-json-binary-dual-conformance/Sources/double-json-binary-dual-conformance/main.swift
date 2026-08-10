// double-json-binary-dual-conformance / main.swift
//
// Purpose: Verify that a single Swift type (Double) can simultaneously
// conform to two sibling format-Codable protocols (JSON.Serializable
// and Binary.Serializable) with no diagnostic conflicts, with usable
// round-trip behavior in both formats, and with deterministic
// call-site disambiguation when both protocol surfaces are in scope.
//
// Hypothesis: Sibling protocols (per the JSON.Serializable family-pattern
// doc, J1d commit 0307edc) compose cleanly on a single type because
// their method signatures differ enough that Swift's overload resolution
// can disambiguate.
//
// Cross-module shape (per [EXP-017]):
//   - swift-json package: declares `Double: JSON.Serializable` (line 419
//     of JSON.Serializable.swift)
//   - Probe library (this package): declares
//     `Double: @retroactive Binary.Serializable`
//   - This executable: imports both + Probe; exercises Double via both
//     surfaces from a third module
//
// Toolchain: Apple Swift 6.3
// Platform: macOS v26
//
// Result: CONFIRMED (V1, V2, V3, V4 Cases A/B/C) + REFUTED prediction (V4 Case D)
// Date: 2026-05-14
//
// Empirical findings (debug + release; both produce identical output):
//
//   V1 CONFIRMED — Double conforms to BOTH JSON.Serializable (from
//                  swift-json) AND Binary.Serializable (from Probe,
//                  this experiment's library target).  Conformances
//                  from two different packages compose cleanly.  Build
//                  receipts: Outputs/build.txt + build-release.txt.
//
//   V2 CONFIRMED — JSON round-trip lossless for all finite values
//                  (0.0, ±1.0, π-approx, ±e-approx, 1e10, 1e-10).
//                  NaN and ±∞ excluded — RFC 8259 §6 cannot represent
//                  them; that's a JSON-format limitation, not a
//                  dual-conformance issue.
//
//   V3 CONFIRMED — Binary.Serializable encodes Double as 8-byte
//                  IEEE-754 bit pattern (native endian).  Bit-pattern
//                  preserved for ALL values including NaN and ±∞
//                  (verified via bitPattern equality, not value
//                  equality).
//
//   V4 Cases A/B/C CONFIRMED — explicit type context disambiguates:
//                  JSON return-type → JSON.Serializable wins; [UInt8]
//                  return-type → Binary.Serializable wins; `into:`
//                  parameter → Binary.Serializable wins.
//
//   V4 Case D REFUTED prediction — `let mystery = Double.serialize(3.14)`
//                  with NO explicit type context was predicted to be
//                  an ambiguity error.  Empirically, Swift's overload
//                  resolution favors the non-generic protocol
//                  requirement (JSON.Serializable's
//                  `serialize(_:) -> JSON`) over the generic
//                  protocol-extension method (Binary.Serializable's
//                  `serialize<Bytes>(_:) -> Bytes`).  `mystery` has
//                  type JSON; no diagnostic.
//
// Family-pattern implication: sibling format-Codable conformances
// declared in different packages compose without conflict on a single
// stdlib type.  Disambiguation is deterministic, not ambiguous —
// consumers can rely on the JSON.Serializable surface being the
// "default" when both are in scope without explicit type context.

import JSON
import Binary_Serializable_Primitives
import Probe
import Darwin

@MainActor
func runTests() {
    var failures: [String] = []

    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures.append(message)
            print("FAIL: \(message)")
        } else {
            print("PASS: \(message)")
        }
    }

    // MARK: - V1: Compile-clean dual conformance

    print("=== V1: Compile-clean dual conformance ===")
    // The fact that this executable links against swift-json (which
    // declares Double: JSON.Serializable) AND Probe (which declares
    // Double: @retroactive Binary.Serializable) IS the V1 evidence.
    //
    // Verify protocol-conformance witnesses exist at compile time via
    // generic-constraint coercion.
    func witnessJSON<T: JSON.Serializable>(_: T.Type) {}
    func witnessBinary<T: Binary.Serializable>(_: T.Type) {}
    witnessJSON(Double.self)
    witnessBinary(Double.self)
    check(true, "Double conforms to both JSON.Serializable and Binary.Serializable")

    // MARK: - V2: JSON round-trip

    print("\n=== V2: JSON round-trip ===")
    let jsonFinites: [Double] = [0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10]
    do {
        for original in jsonFinites {
            // Disambiguate by explicit return-type annotation.
            let json: JSON = Double.serialize(original)
            let recovered = try Double.deserialize(json)
            check(recovered == original, "Round-trip Double(\(original)) via JSON")
        }
    } catch {
        check(false, "V2 unexpected throw: \(error)")
    }

    // MARK: - V3: Binary serialize (encode-only protocol; bit-pattern round-trip)

    print("\n=== V3: Binary serialize ===")
    let binaryAll: [Double] = [0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, .infinity, -.infinity, .nan]
    for original in binaryAll {
        var buf: [UInt8] = []
        Double.serialize(original, into: &buf)
        check(buf.count == 8, "Double serializes to 8 bytes for \(original)")

        // Reconstruct via bitPattern; verify encode is lossless.
        var bits: UInt64 = 0
        for (i, byte) in buf.enumerated() {
            bits |= UInt64(byte) << (i * 8) // native (little) endian on macOS arm64/x86_64
        }
        let recovered = Double(bitPattern: bits)
        // Bit-pattern equality handles NaN correctly.
        check(
            recovered.bitPattern == original.bitPattern,
            "Bit-pattern preserved through Binary.serialize for \(original)"
        )
    }

    // Convenience extension on Binary.Serializable:
    let original: Double = 3.14159
    let bytes: [UInt8] = original.bytes
    check(bytes.count == 8, "Double.bytes convenience returns 8 bytes")

    // MARK: - V4: Call-site disambiguation

    print("\n=== V4: Call-site disambiguation ===")

    // Case A: explicit JSON return type — JSON.Serializable wins.
    let asJSON: JSON = Double.serialize(3.14)
    check(asJSON.isNumber, "Double.serialize(3.14) with JSON return-type → JSON.Serializable")

    // Case B: explicit `into:` parameter — Binary.Serializable wins
    // (only it has that parameter shape).
    var bufB: [UInt8] = []
    Double.serialize(3.14, into: &bufB)
    check(bufB.count == 8, "Double.serialize(3.14, into: &buf) → Binary.Serializable")

    // Case C: explicit byte-array return type — Binary.Serializable
    // wins via its generic single-arg extension.
    let asBytes: [UInt8] = Double.serialize(3.14)
    check(asBytes.count == 8, "Double.serialize(3.14) with [UInt8] return-type → Binary.Serializable")

    // Case D: implicit return type — empirically, Swift's overload
    // resolution favors JSON.Serializable's non-generic
    // `serialize(_:) -> JSON` over Binary.Serializable's generic
    // `serialize<Bytes>(_:) -> Bytes` extension.  No ambiguity error;
    // resolution is deterministic.  This was originally predicted to
    // be an ambiguity error; the prediction is REFUTED.
    let mystery = Double.serialize(3.14)
    check(
        type(of: mystery) == JSON.self,
        "Case D resolves deterministically to JSON.Serializable (not ambiguous)"
    )

    // MARK: - Summary

    print("\n=== Summary ===")
    if failures.isEmpty {
        print("All checks PASSED")
    } else {
        print("\(failures.count) check(s) FAILED:")
        for f in failures { print("  \(f)") }
        Darwin.exit(1)
    }
}

runTests()
