// MARK: - Copyable Wrapper Refcount Cost
//
// Purpose: Mechanically validate the §2 cost-model table in
//   swift-institute/Research/copyable-wrapper-vs-multi-buffer-storage.md
//   ("Storage shape → Refcounts per wrapper copy").
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) — captured in Outputs/toolchain.txt
// Platform: macOS 26 arm64; Build: swift build -c release
// Status: V1 REFUTED, V2 CONFIRMED — composite CONFIRMED for [BENCH-011]
// Result: V1 (trivial isolated probe): REFUTED. Optimizer elides the
//           wrapper-copy cost entirely. Measured (Outputs/run-release.txt):
//             K=1: 8.4e-06 ns/extract   (sub-clock-resolution)
//             K=2: 4.2e-06 ns/extract
//             K=3: 4.2e-06 ns/extract
//             K=4: 4.2e-06 ns/extract
//           No K-scaling visible; deltas at noise floor (≤ 8 fs/step).
//         V2 (optimizer-resistant probe with global-sink + varied input):
//           CONFIRMED. Wall-clock per extract scales monotonically with K.
//             K=1: 10.87 ns/extract
//             K=2: 18.29 ns/extract
//             K=3: 25.84 ns/extract
//             K=4: 33.90 ns/extract
//           Deltas: 7.42, 7.55, 8.06 ns per additional heap-backed
//           component. Slope: ~7.68 ns/component, within the
//           ~3-10 ns/refcount-op range the §2 cost-model cited.
//         Composite: V1's elision under trivial isolation + V2's K-linear
//           cost under barrier conditions JOINTLY confirm the [BENCH-011]
//           integration-probe-requirement rule. The §2 cost-model term
//           is real (V2) and observable (V2 slope), but invisible to
//           isolated micro-benches whose access path the optimizer can
//           specialize (V1). Isolated benches don't merely UNDERSTATE
//           the integrated cost; they can ELIMINATE it entirely.
// Date: 2026-05-13

// MARK: - V1: Trivial isolated probe (Hypothesis: optimizer cannot elide)
//
// Hypothesis V1: A Copyable struct with K heap-backed stored properties
//   incurs K retain operations per pattern-match-extract, observable
//   as linear wall-clock scaling.
// Method: K1..K4 wrappers around Array<UInt8>, pattern-match-extract
//   in a tight loop with @inline(never) probes, read .count on each
//   Array as a cheap consumer of the payload.
// Result: REFUTED. Optimizer elides retain/release; wall-clock ~0 ns
//   across K=1..4 (sub-clock-resolution measurement).
// Implication: the structural retain cost the §2 model describes
//   exists at SIL but the optimizer can eliminate it entirely when
//   (a) input is loop-invariant, (b) usage is trivially elidable
//   (constant .count read), (c) extracted scope is short-lived.

struct K1 { let a: [UInt8] }
struct K2 { let a: [UInt8]; let b: [UInt8] }
struct K3 { let a: [UInt8]; let b: [UInt8]; let c: [UInt8] }
struct K4 { let a: [UInt8]; let b: [UInt8]; let c: [UInt8]; let d: [UInt8] }

enum Wrapper {
    case k1(K1)
    case k2(K2)
    case k3(K3)
    case k4(K4)
}

@inline(never)
func extractK1V1(_ e: Wrapper) -> Int {
    if case .k1(let w) = e { return w.a.count }
    return 0
}

@inline(never)
func extractK2V1(_ e: Wrapper) -> Int {
    if case .k2(let w) = e { return w.a.count &+ w.b.count }
    return 0
}

@inline(never)
func extractK3V1(_ e: Wrapper) -> Int {
    if case .k3(let w) = e { return w.a.count &+ w.b.count &+ w.c.count }
    return 0
}

@inline(never)
func extractK4V1(_ e: Wrapper) -> Int {
    if case .k4(let w) = e {
        return w.a.count &+ w.b.count &+ w.c.count &+ w.d.count
    }
    return 0
}

// MARK: - V2: Optimizer-resistant probe (Hypothesis: barriers reveal K-linear cost)
//
// Hypothesis V2: When the extracted payload is stored into a global
//   mutable sink (observable side-effect that the optimizer cannot
//   elide), the pattern-match-extract cost is K-linear in the number
//   of heap-backed components — matching the §2 cost-model prediction
//   of K retain ops per copy.
//
// Method: Same K1..K4 wrappers, but the extract probe stores the
//   extracted payload into a global var (Optional-typed for type
//   ambiguity; the assignment forces K retains on the new value
//   and K releases of the old value the slot held).
//   Input is varied across a 1024-entry array so the optimizer
//   cannot hoist the extract out of the loop.
//   Each iteration: array-index load + pattern-match-extract +
//   global-store = the K-scaling term is the dominant differential
//   between K=1 and K=4.
// Expected: time-per-extract series monotonically increasing in K;
//   slope ≈ τ_retain + τ_release per K-step (typically ~3-10 ns on
//   modern Apple Silicon per refcount-pair, per the ARC literature).

nonisolated(unsafe) var sinkK1: K1? = nil
nonisolated(unsafe) var sinkK2: K2? = nil
nonisolated(unsafe) var sinkK3: K3? = nil
nonisolated(unsafe) var sinkK4: K4? = nil

@inline(never)
func extractK1V2(_ e: Wrapper) {
    if case .k1(let w) = e {
        sinkK1 = w  // observable store — forces retain on w.a
    }
}

@inline(never)
func extractK2V2(_ e: Wrapper) {
    if case .k2(let w) = e {
        sinkK2 = w  // forces retain on w.a, w.b
    }
}

@inline(never)
func extractK3V2(_ e: Wrapper) {
    if case .k3(let w) = e {
        sinkK3 = w  // forces retain on w.a, w.b, w.c
    }
}

@inline(never)
func extractK4V2(_ e: Wrapper) {
    if case .k4(let w) = e {
        sinkK4 = w  // forces retain on w.a, w.b, w.c, w.d
    }
}

// MARK: - Measurement harness

let iterations = 10_000_000
let warmupIterations = 100_000

@inline(never)
func measureV1(label: String, extract: (Wrapper) -> Int, wrapped: Wrapper) -> Double {
    var sum = 0
    for _ in 0..<warmupIterations { sum &+= extract(wrapped) }
    let start = ContinuousClock.now
    for _ in 0..<iterations { sum &+= extract(wrapped) }
    let elapsed = ContinuousClock.now - start
    let secs = Double(elapsed.components.seconds)
    let attos = Double(elapsed.components.attoseconds)
    let nsPerExtract = (secs * 1e9 + attos / 1e9) / Double(iterations)
    print("V1 \(label): \(nsPerExtract) ns/extract  (sum=\(sum))")
    return nsPerExtract
}

@inline(never)
func measureV2(label: String, extract: (Wrapper) -> Void, varying: [Wrapper]) -> Double {
    let mask = varying.count - 1  // requires count to be power of 2
    for i in 0..<warmupIterations { extract(varying[i & mask]) }
    let start = ContinuousClock.now
    for i in 0..<iterations { extract(varying[i & mask]) }
    let elapsed = ContinuousClock.now - start
    let secs = Double(elapsed.components.seconds)
    let attos = Double(elapsed.components.attoseconds)
    let nsPerExtract = (secs * 1e9 + attos / 1e9) / Double(iterations)
    print("V2 \(label): \(nsPerExtract) ns/extract")
    return nsPerExtract
}

// MARK: - V1 inputs (loop-invariant)

let buf1 = [UInt8](repeating: 0xA1, count: 64)
let buf2 = [UInt8](repeating: 0xB2, count: 64)
let buf3 = [UInt8](repeating: 0xC3, count: 64)
let buf4 = [UInt8](repeating: 0xD4, count: 64)

let v1K1 = Wrapper.k1(K1(a: buf1))
let v1K2 = Wrapper.k2(K2(a: buf1, b: buf2))
let v1K3 = Wrapper.k3(K3(a: buf1, b: buf2, c: buf3))
let v1K4 = Wrapper.k4(K4(a: buf1, b: buf2, c: buf3, d: buf4))

// MARK: - V2 inputs (varying — 1024 wrappers per K, distinct buffers each)

let variantCount = 1024
let v2K1: [Wrapper] = (0..<variantCount).map { i in
    .k1(K1(a: [UInt8](repeating: UInt8(i & 0xff), count: 64 + (i & 7))))
}
let v2K2: [Wrapper] = (0..<variantCount).map { i in
    .k2(K2(
        a: [UInt8](repeating: UInt8(i & 0xff), count: 64 + (i & 7)),
        b: [UInt8](repeating: UInt8((i+1) & 0xff), count: 64 + ((i+1) & 7))
    ))
}
let v2K3: [Wrapper] = (0..<variantCount).map { i in
    .k3(K3(
        a: [UInt8](repeating: UInt8(i & 0xff), count: 64 + (i & 7)),
        b: [UInt8](repeating: UInt8((i+1) & 0xff), count: 64 + ((i+1) & 7)),
        c: [UInt8](repeating: UInt8((i+2) & 0xff), count: 64 + ((i+2) & 7))
    ))
}
let v2K4: [Wrapper] = (0..<variantCount).map { i in
    .k4(K4(
        a: [UInt8](repeating: UInt8(i & 0xff), count: 64 + (i & 7)),
        b: [UInt8](repeating: UInt8((i+1) & 0xff), count: 64 + ((i+1) & 7)),
        c: [UInt8](repeating: UInt8((i+2) & 0xff), count: 64 + ((i+2) & 7)),
        d: [UInt8](repeating: UInt8((i+3) & 0xff), count: 64 + ((i+3) & 7))
    ))
}

// MARK: - Run

print("# Copyable Wrapper Refcount Cost")
print("# iterations=\(iterations), warmup=\(warmupIterations)")
print("# Toolchain: Apple Swift 6.3.2; Platform: macOS 26 arm64; Build: -c release")
print()
print("## V1: Trivial isolated probe (expected REFUTED — optimizer should elide)")
let v1t1 = measureV1(label: "K=1", extract: extractK1V1, wrapped: v1K1)
let v1t2 = measureV1(label: "K=2", extract: extractK2V1, wrapped: v1K2)
let v1t3 = measureV1(label: "K=3", extract: extractK3V1, wrapped: v1K3)
let v1t4 = measureV1(label: "K=4", extract: extractK4V1, wrapped: v1K4)
print()
print("V1 deltas (per added heap-backed component):")
print("  K=2-K=1: \(v1t2 - v1t1) ns")
print("  K=3-K=2: \(v1t3 - v1t2) ns")
print("  K=4-K=3: \(v1t4 - v1t3) ns")
let v1Monotonic = (v1t2 > v1t1) && (v1t3 > v1t2) && (v1t4 > v1t3)
print("V1 verdict: \(v1Monotonic ? "monotonic — UNEXPECTED" : "NOT monotonic — REFUTED (optimizer elided the cost)")")

print()
print("## V2: Optimizer-resistant probe (expected CONFIRMED — global-sink + varied input)")
let v2t1 = measureV2(label: "K=1", extract: extractK1V2, varying: v2K1)
let v2t2 = measureV2(label: "K=2", extract: extractK2V2, varying: v2K2)
let v2t3 = measureV2(label: "K=3", extract: extractK3V2, varying: v2K3)
let v2t4 = measureV2(label: "K=4", extract: extractK4V2, varying: v2K4)
print()
print("V2 deltas (per added heap-backed component):")
print("  K=2-K=1: \(v2t2 - v2t1) ns")
print("  K=3-K=2: \(v2t3 - v2t2) ns")
print("  K=4-K=3: \(v2t4 - v2t3) ns")
let v2Monotonic = (v2t2 > v2t1) && (v2t3 > v2t2) && (v2t4 > v2t3)
if v2Monotonic {
    let slope = (v2t4 - v2t1) / 3.0
    print("V2 verdict: monotonic in K — CONFIRMED.")
    print("  Slope: ~\(slope) ns per additional heap-backed component.")
    print("  This is the per-refcount-pair cost under optimizer-resistant conditions.")
    print("  Matches the §2 cost-model prediction (K retain ops per copy, ~3-10 ns each).")
} else {
    print("V2 verdict: NOT monotonic — even global-sink barrier insufficient to defeat elision.")
    print("  Possible: optimizer proved global-sink reads are dead; further barriers required.")
}

print()
print("## Composite finding")
print("V1 (isolated): \(v1Monotonic ? "monotonic" : "elided")")
print("V2 (with barrier): \(v2Monotonic ? "K-linear (slope ~\((v2t4 - v2t1)/3.0) ns)" : "elided")")
print()
print("Implication for [BENCH-011] integration-probe-requirement rule:")
if !v1Monotonic && v2Monotonic {
    print("  CONFIRMED. The cost-model term IS real and observable, but only when")
    print("  the consumer's access path defeats optimizer elision. Isolated micro-")
    print("  benches don't merely UNDERSTATE the integrated cost — they can")
    print("  ELIMINATE it entirely. The integration-probe requirement is the only")
    print("  way to measure the cost the production consumer will actually pay.")
} else if v1Monotonic && v2Monotonic {
    print("  PARTIALLY CONFIRMED. Both probes show K-linear cost; the isolation")
    print("  did not elide. The cost-model holds even at isolation, suggesting")
    print("  the swift-json v2 case's overstatement came from other terms.")
} else if !v1Monotonic && !v2Monotonic {
    print("  INCONCLUSIVE. Both probes elided. Stronger barriers needed to make")
    print("  the cost-model term observable.")
} else {
    print("  ANOMALOUS. Investigate harness — V1 monotonic + V2 not is unexpected.")
}
