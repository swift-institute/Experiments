// Check #3 — withContiguousStorageIfAvailable engagement (regression check)
//
// Verifies the Phase A0 spike #3 premise from
// swift-institute/Research/streaming-json-deserialize-comparative-analysis.md
// §5 (carried forward from parse-performance-architecture.md v1.0.1 §8's
// Tier-4 finding).
//
// This is a REGRESSION CHECK — the Tier-4 spike at
//   swift-foundations/swift-json/Experiments/parse-performance-tier-4-feasibility/Sources/check-contiguous-storage/main.swift
// already verified these engagements under Swift 6.3+ on macOS 26 arm64.
// Re-run under the CURRENT toolchain to confirm no regression. If any
// previously-engaging shape regressed, RED — the dispatch fork at
// `RFC_8259.Decode.callAsFunction` (and the planned analogous fork at
// `JSON.Serializable.from(eventDecodingJsonBytes:)` per Option B §4.3)
// would silently degrade to the slow path for affected inputs.
//
// Probes (per the spike brief):
//   1. Native Swift String (small)        — should engage
//   2. Native Swift String (long ASCII)   — should engage
//   3. [UInt8]                            — should engage
//   4. ContiguousArray<UInt8>             — should engage
//   5. ArraySlice<UInt8>                  — should engage
//   6. Bridged NSString (small, Apple)    — should engage (per Tier 4 finding)
//   7. Bridged NSString (long, Apple)     — should engage (per Tier 4 finding)
//   8. Non-contiguous lazy collection     — should NOT engage (slow-path test)

import Foundation  // permitted in spike tooling — confirms NSString bridging

// MARK: - Helpers

struct ProbeResult {
    let label: String
    let count: Int
    let expectedEngagement: Bool
    let actualEngagement: Bool
}

nonisolated(unsafe) var results: [ProbeResult] = []

func probeUTF8(label: String, _ string: String, expected: Bool) {
    let utf8 = string.utf8
    let count = utf8.count
    let res = utf8.withContiguousStorageIfAvailable { buf -> Int in
        // Touch the buffer so the optimizer doesn't elide the call.
        var sum: UInt64 = 0
        for b in buf { sum = sum &+ UInt64(b) }
        return Int(truncatingIfNeeded: sum)
    }
    let engaged = res != nil
    results.append(ProbeResult(label: label, count: count, expectedEngagement: expected, actualEngagement: engaged))
}

func probeCollection<C: Collection>(label: String, _ collection: C, expected: Bool) where C.Element == UInt8 {
    let count = collection.count
    let res = collection.withContiguousStorageIfAvailable { buf -> Int in
        var sum: UInt64 = 0
        for b in buf { sum = sum &+ UInt64(b) }
        return Int(truncatingIfNeeded: sum)
    }
    let engaged = res != nil
    results.append(ProbeResult(label: label, count: count, expectedEngagement: expected, actualEngagement: engaged))
}

print("=== check-contiguous-storage ===")
print("Regression check on withContiguousStorageIfAvailable engagement")
print("for the shapes RFC_8259.Decode / JSON.Span.EventStream callers actually pass.")
print("")

// Probe 1: small ASCII literal (small-string optimization territory)
probeUTF8(label: "1. native String (small ASCII, 15 chars)",
          "hello world JSON",
          expected: true)

// Probe 2: longer ASCII string built at runtime (heap-backed)
let longerString = String(repeating: "abc", count: 1000)
probeUTF8(label: "2. native String (long ASCII, 3000 chars)",
          longerString,
          expected: true)

// Probe 3: [UInt8]
let arrayBytes: [UInt8] = Array("decoded from bytes for span test".utf8)
probeCollection(label: "3. [UInt8] (32 elements)",
                arrayBytes,
                expected: true)

// Probe 4: ContiguousArray<UInt8>
let contiguousBytes: ContiguousArray<UInt8> = ContiguousArray("contiguous array of bytes".utf8)
probeCollection(label: "4. ContiguousArray<UInt8> (\(contiguousBytes.count) elements)",
                contiguousBytes,
                expected: true)

// Probe 5: ArraySlice<UInt8>
let parentArray: [UInt8] = Array("parent buffer for arrayslice probe — middle of this string is the slice".utf8)
let sliceBytes: ArraySlice<UInt8> = parentArray[10..<60]
probeCollection(label: "5. ArraySlice<UInt8> (\(sliceBytes.count) elements)",
                sliceBytes,
                expected: true)

// Probe 6: Bridged NSString (small) — Apple-platform-only shape.
// Per Tier 4's finding, bridged NSString HITS the contiguous path on
// macOS 26 arm64. The Tier-4 architecture doc had projected this as a
// slow-path case; empirically it was not. Re-verify.
let nsStringSmall = NSString(string: "bridged from NSString")
let bridgedSmall = nsStringSmall as String
probeUTF8(label: "6. NSString-as-String (bridged, small)",
          bridgedSmall,
          expected: true)

// Probe 7: Bridged NSString (longer)
let nsStringLong = NSString(string: String(repeating: "x", count: 200))
let bridgedLong = nsStringLong as String
probeUTF8(label: "7. NSString-as-String (bridged, long, 200 chars)",
          bridgedLong,
          expected: true)

// Probe 8: Non-contiguous lazy collection — slow-path test.
// A LazyMapSequence / .lazy.map view does NOT carry contiguous storage,
// so withContiguousStorageIfAvailable should return nil. This is the
// canary that confirms the API is actually checking storage shape,
// not just always returning a result.
//
// Using a Repeated<UInt8> ⊕ a .lazy.map view to construct a non-array
// shape that conforms to Collection but has no contiguous storage.
//
// AnyCollection<UInt8> over a lazy map is a textbook non-contiguous
// Collection. The implementation's withContiguousStorageIfAvailable
// has no specialised fast path — the default protocol-method
// implementation returns nil.
struct NonContiguousByteCollection: Collection {
    typealias Element = UInt8
    typealias Index = Int

    private let length: Int

    init(length: Int) { self.length = length }

    var startIndex: Int { 0 }
    var endIndex: Int { length }
    func index(after i: Int) -> Int { i &+ 1 }
    subscript(position: Int) -> UInt8 { UInt8(truncatingIfNeeded: position) }
    // Deliberately do NOT override withContiguousStorageIfAvailable —
    // the default Collection implementation returns nil.
}

let lazyBytes = NonContiguousByteCollection(length: 64)
probeCollection(label: "8. NonContiguousByteCollection (64 elements, no fast path)",
                lazyBytes,
                expected: false)

// ------------------------------------------------------------
// Report
// ------------------------------------------------------------
print("--- Probe results ---")
print("")

var regressionCount = 0
var passCount = 0

for r in results {
    let dispositionMatches = r.actualEngagement == r.expectedEngagement
    let engagedLabel = r.actualEngagement ? "engaged" : "did NOT engage"
    let expectedLabel = r.expectedEngagement ? "engage" : "NOT engage"

    if dispositionMatches {
        passCount &+= 1
        print("  [PASS] \(r.label): count=\(r.count), \(engagedLabel)")
    } else {
        regressionCount &+= 1
        print("  [FAIL] \(r.label): count=\(r.count), \(engagedLabel), expected to \(expectedLabel)")
    }
}

print("")
print("  pass: \(passCount)")
print("  fail (regression): \(regressionCount)")

// ------------------------------------------------------------
// Disposition
// ------------------------------------------------------------
print("")
print("--- Disposition ---")
print("")

if regressionCount == 0 {
    print("PREMISE 3: GREEN")
    print("  All seven previously-engaging shapes (native String small + long,")
    print("  [UInt8], ContiguousArray<UInt8>, ArraySlice<UInt8>, bridged")
    print("  NSString small + long) continue to engage on the current")
    print("  toolchain. The non-contiguous slow-path canary correctly")
    print("  fails to engage. No regression vs the Tier 4 spike's finding.")
    print("  Option B's `from(eventDecodingJsonBytes:)` dispatch fork")
    print("  (mirroring RFC_8259.Decode.callAsFunction) will reach the")
    print("  Span fast path for all real-consumer input shapes.")
} else {
    print("PREMISE 3: RED")
    print("  \(regressionCount) shape(s) regressed vs the Tier 4 finding.")
    print("  See [FAIL] lines above for which shapes lost their fast path.")
    print("  This affects RFC_8259.Decode.callAsFunction's dispatch and")
    print("  Option B's planned `from(eventDecodingJsonBytes:)` entry")
    print("  point — affected callers will silently fall to the slow")
    print("  path. Phase A1 must either avoid the regressed shapes at")
    print("  the call site or absorb the dispatch-cost change in the")
    print("  measurement gate.")
}
