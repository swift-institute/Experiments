// MARK: - In-body .map / .flatMap Anomaly Investigation
//
// Purpose: Root-cause the ~21x slowdown observed when `seq.map { ... }` is
//          written inside a `Swift.Array.Builder` body, vs `Builder { 0..<N }`
//          via the Sequence overload (which is fast).
//
// Toolchain: Apple Swift 6.3.1
// Date: 2026-05-07
//
// Status: REFUTED — the slowdown is NOT a builder anomaly. It is the
//         intrinsic cost of stdlib's `Collection.map` (and `.flatMap`,
//         and `.lazy.map`) when called with a closure literal. Same cost
//         whether inside a builder body or standalone.
//
// Result (release mode, Swift 6.3.1, N=100, 50000 iterations):
//
//   V1  imperative for+append                                      ~340-430 ns
//   V2  Builder { (0..<N).map { *2 } }            INLINE          ~4200 ns  (10x)
//   V3  let m = ..; Builder { m }                  PRE-MAT          ~4000-7700 ns
//   V4  Builder { Array((0..<N).map { *2 }) }      EXPLICIT WRAP   ~3950 ns
//   V5  Builder { (...).map { *2 } as [Int] }      TYPED           ~3940 ns
//   V6  Builder { (0..<N).flatMap { [*2] } }       INLINE          ~5500 ns
//   V7  let m = ..flatMap; Builder { m }           PRE-MAT          ~5650 ns
//   V8  (0..<N).map { *2 }                         STANDALONE      ~4083 ns  (9.6x)
//   V9  Builder { Array(0..<N) }                   NO TRANSFORM      ~42 ns  (FAST)
//   V10 Builder { (0..<N).lazy.map { *2 } }        LAZY            ~4000 ns
//   V11 Builder { fileScopeLet }                   CONST              ~0 ns  (hoisted)
//   V12 Builder { 0..<N }                          SEQUENCE          ~43 ns  (FAST)
//   V13 Builder { (0..<N).sameModuleMap { *2 } }   SAME-MODULE MAP  ~210 ns  (FAST)
//   V14 (0..<N).sameModuleMap { *2 }               STANDALONE       ~210 ns  (FAST)
//   V15 (0..<N).sameModuleMapRethrows { *2 }       STANDALONE       ~210 ns  (FAST)
//   V16 Builder { ...sameModuleMapRethrows { *2 } } IN BUILDER       ~210 ns  (FAST)
//
// Decisive comparisons:
//
//   V13 / V2  = 0.05x  (same-module map is 20x FASTER than stdlib .map in a builder)
//   V14 / V8  = 0.05x  (same-module map is 20x FASTER than stdlib .map standalone)
//   V8  / V14 = 19.4x  (stdlib .map is 19x SLOWER than the equivalent same-module map)
//   V13 / V14 = 1.00x  (builder adds no measurable overhead vs standalone)
//   V15 / V14 = 1.00x  (rethrows annotation adds no measurable overhead)
//
// Conclusions:
//
//   1. The "21x anomaly" was the cost of stdlib `.map`, NOT the builder.
//      Builder adds zero measurable overhead vs standalone (V13 ≈ V14).
//
//   2. The slowness is specific to stdlib `Collection.map`. The same
//      operation written as an @inlinable method in the consumer module
//      (V13/V14) is on par with imperative — actually faster than imperative
//      `for+append` at 0.5x.
//
//   3. The slowdown is not caused by `rethrows` (V15 with rethrows is fast).
//      Cause is not the call signature.
//
//   4. The slowdown is not caused by overload resolution between Sequence
//      and [Element] builder overloads (V4 with explicit Array() wrap is
//      same speed as V2 inline; V5 with explicit type annotation same).
//
//   5. The slowdown is not caused by lazy vs eager (V10 lazy.map ≈ V2 .map).
//
// Likely cause: stdlib's `Collection.map` does not specialize the closure
// at the consumer call site despite both `map` and the closure being eligible
// for specialization. The closure is dispatched through a generic boundary,
// adding ~40 ns per element of indirect-call + protocol-dispatch overhead at
// N=100. A same-module @inlinable map (V13/V14) sees full specialization
// and costs ~2 ns per element.
//
// Implications for our shipped builder code:
//
//   - The Sequence overload (Option G) is correct and remains FAST for
//     direct sequences (Range, Array, Set).
//   - The for-loop in builder body slowdown is REAL and SEPARATE — that's
//     SE-0289's per-iteration buildExpression([Element]) allocation, not
//     this .map issue.
//   - "Use seq.map for transforms in builder bodies" is poor advice — users
//     pay stdlib .map's ~10x cost regardless. The same advice applies
//     OUTSIDE builders, so it's a Swift-stdlib issue, not a builder issue.
//   - For best transform perf, users should write an @inlinable helper in
//     their own module or use an imperative for-loop. Both bypass the
//     stdlib .map specialization gap.
//
// This investigation REFUTES the framing in the original blog post draft
// that there is a builder-specific transform issue. The post should be
// revised to acknowledge that .map (in or out of a builder) is intrinsically
// slow and route users toward the Sequence overload (direct sequences) or
// imperative loops (transforms) accordingly.

import Standard_Library_Extensions

@inline(never)
func blackHole<T>(_ value: T) {
    withExtendedLifetime(value) { () }
}

func measure(_ name: String, iterations: Int, _ body: () -> Void) -> Double {
    for _ in 0..<min(100, iterations / 10) { body() }
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        for _ in 0..<iterations { body() }
    }
    let nanos = elapsed.components.attoseconds / 1_000_000_000 + elapsed.components.seconds * 1_000_000_000
    let perIter = Double(nanos) / Double(iterations)
    let padded = padRight(name, to: 60)
    print("  \(padded) \(formatNs(perIter)) ns/iter")
    return perIter
}

func padRight(_ s: String, to width: Int) -> String {
    var out = s
    while out.count < width { out += " " }
    return out
}

func padLeft(_ s: String, to width: Int) -> String {
    var out = s
    while out.count < width { out = " " + out }
    return out
}

func formatNs(_ v: Double) -> String {
    let rounded = (v * 10).rounded() / 10
    return padLeft("\(rounded)", to: 12)
}

func formatRatio(_ v: Double) -> String {
    let rounded = (v * 100).rounded() / 100
    return padLeft("\(rounded)x", to: 10)
}

print("In-body .map/.flatMap anomaly investigation")
print("Build mode: \(_isDebugAssertConfiguration() ? "DEBUG" : "RELEASE")")
print(String(repeating: "=", count: 78))

// All cases at N=100 unless otherwise noted

let N = 100
let iterations = 50_000

// File-scope constant for V11
nonisolated(unsafe) let mappedConst: [Int] = (0..<N).map { $0 * 2 }

print("\n=== N=\(N), iterations=\(iterations) ===\n")

// V1: imperative baseline (`var; reserveCapacity; for+append`)
let v1 = measure("V1  imperative *2 (baseline)", iterations: iterations) {
    var a: [Int] = []
    a.reserveCapacity(N)
    for i in 0..<N { a.append(i * 2) }
    blackHole(a)
}

// V2: inline .map in builder body — the anomaly case
let v2 = measure("V2  Array<Int> { (0..<N).map { f } } — INLINE", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).map { $0 * 2 }
    }
    blackHole(a)
}

// V3: pre-materialized .map → builder
let v3 = measure("V3  let m = ...; Array<Int> { m } — PRE-MATERIALIZED", iterations: iterations) {
    let m = (0..<N).map { $0 * 2 }
    let a = Swift.Array<Int> {
        m
    }
    blackHole(a)
}

// V4: explicit Array() wrap forces [Element] overload selection
let v4 = measure("V4  Array<Int> { Array((0..<N).map { f }) } — EXPLICIT WRAP", iterations: iterations) {
    let a = Swift.Array<Int> {
        Swift.Array((0..<N).map { $0 * 2 })
    }
    blackHole(a)
}

// V5: explicit type annotation in body
let v5 = measure("V5  Array<Int> { (...).map { f } as [Int] } — TYPED", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).map { $0 * 2 } as [Int]
    }
    blackHole(a)
}

// V6: inline .flatMap in builder body — does anomaly generalize?
let v6 = measure("V6  Array<Int> { (0..<N).flatMap { [f] } } — INLINE", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).flatMap { [$0 * 2] }
    }
    blackHole(a)
}

// V7: pre-materialized .flatMap
let v7 = measure("V7  let m = (..).flatMap; Array { m } — PRE-MATERIALIZED", iterations: iterations) {
    let m: [Int] = (0..<N).flatMap { [$0 * 2] }
    let a = Swift.Array<Int> {
        m
    }
    blackHole(a)
}

// V8: standalone .map (no builder)
let v8 = measure("V8  (0..<N).map { f } — STANDALONE (no builder)", iterations: iterations) {
    let m = (0..<N).map { $0 * 2 }
    blackHole(m)
}

// V9: builder with Range only (known-fast baseline)
let v9 = measure("V9  Array<Int> { Array(0..<N) } — KNOWN FAST (no transform)", iterations: iterations) {
    let a = Swift.Array<Int> {
        Swift.Array(0..<N)
    }
    blackHole(a)
}

// V10: inline .lazy.map in builder body
let v10 = measure("V10 Array<Int> { (0..<N).lazy.map { f } } — LAZY MAP INLINE", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).lazy.map { $0 * 2 }
    }
    blackHole(a)
}

// V11: builder body just the [Element] result (no .map call inside body)
//      Same as V3 but written differently to confirm
let v11 = measure("V11 Array<Int> { mappedConst } — CONST PRE-MAT", iterations: iterations) {
    let a = Swift.Array<Int> {
        mappedConst
    }
    blackHole(a)
}

// V12: bare Range in body (Sequence overload path)
let v12 = measure("V12 Array<Int> { 0..<N } — BARE RANGE (Sequence overload)", iterations: iterations) {
    let a = Swift.Array<Int> {
        0..<N
    }
    blackHole(a)
}

// V13: custom @inlinable map — same shape as stdlib .map but in OUR module
//      If V13 is fast, the issue is stdlib .map's cross-module specialization,
//      not the operation itself.
extension Collection {
    @inlinable
    func sameModuleMap<T>(_ transform: (Element) -> T) -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for x in self {
            result.append(transform(x))
        }
        return result
    }

    /// Mirrors stdlib `Collection.map`'s exact signature with `rethrows`
    /// to test whether the rethrows machinery is what defeats specialization.
    @inlinable
    func sameModuleMapRethrows<T>(_ transform: (Element) throws -> T) rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for x in self {
            result.append(try transform(x))
        }
        return result
    }
}

let v13 = measure("V13 Array<Int> { (0..<N).sameModuleMap { f } } — SAME-MODULE MAP", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).sameModuleMap { $0 * 2 }
    }
    blackHole(a)
}

let v14 = measure("V14 (0..<N).sameModuleMap { f } — STANDALONE", iterations: iterations) {
    let m = (0..<N).sameModuleMap { $0 * 2 }
    blackHole(m)
}

let v15 = measure("V15 (0..<N).sameModuleMapRethrows { f } — STANDALONE rethrows", iterations: iterations) {
    let m = (0..<N).sameModuleMapRethrows { $0 * 2 }
    blackHole(m)
}

let v16 = measure("V16 Array<Int> { (0..<N).sameModuleMapRethrows { f } } — IN BUILDER rethrows", iterations: iterations) {
    let a = Swift.Array<Int> {
        (0..<N).sameModuleMapRethrows { $0 * 2 }
    }
    blackHole(a)
}

print("\n" + String(repeating: "=", count: 110))
print("Summary — all ratios are vs V1 (imperative baseline)")
print(String(repeating: "=", count: 110))

func report(_ label: String, _ ns: Double) {
    let ratio = ns / v1
    let padded = padRight(label, to: 60)
    let nsCol = formatNs(ns)
    let ratioCol = formatRatio(ratio)
    let verdict: String
    if ratio < 0.5 { verdict = "MUCH FASTER" }
    else if ratio < 1.0 { verdict = "FASTER" }
    else if ratio < 1.5 { verdict = "ON PAR" }
    else if ratio < 3.0 { verdict = "SLOW" }
    else { verdict = "MUCH SLOWER" }
    print("  \(padded) \(nsCol)  \(ratioCol)  \(verdict)")
}

report("V1  imperative *2", v1)
report("V2  inline .map (anomaly)", v2)
report("V3  pre-materialized .map", v3)
report("V4  explicit Array() wrap", v4)
report("V5  explicit type annotation", v5)
report("V6  inline .flatMap", v6)
report("V7  pre-materialized .flatMap", v7)
report("V8  standalone .map (no builder)", v8)
report("V9  Array<Int> { Array(0..<N) } (no transform)", v9)
report("V10 inline .lazy.map", v10)
report("V11 const pre-materialized", v11)
report("V12 bare Range (Sequence overload)", v12)
report("V13 @inlinable same-module map (in builder)", v13)
report("V14 @inlinable same-module map (standalone)", v14)
report("V15 same-module map RETHROWS (standalone)", v15)
report("V16 same-module map RETHROWS (in builder)", v16)

print("\nKey discriminators:")
print("  V2 vs V3 ratio (inline .map / pre-mat):    \(formatRatio(v2 / v3))")
print("  V2 vs V4 ratio (inline .map / explicit Array wrap): \(formatRatio(v2 / v4))")
print("  V2 vs V5 ratio (inline .map / typed annotation):    \(formatRatio(v2 / v5))")
print("  V6 vs V7 ratio (inline .flatMap / pre-mat):         \(formatRatio(v6 / v7))")
print("  V8 vs V3 ratio (standalone .map / pre-mat builder): \(formatRatio(v8 / v3))")
print("  V11 vs V3 ratio (const pre-mat / let pre-mat):      \(formatRatio(v11 / v3))")
print("  V13 vs V2 ratio (same-module map / stdlib .map in builder): \(formatRatio(v13 / v2))")
print("  V14 vs V8 ratio (same-module map / stdlib .map standalone): \(formatRatio(v14 / v8))")
print("  V13 vs V1 ratio (same-module map in builder / imperative):  \(formatRatio(v13 / v1))")
