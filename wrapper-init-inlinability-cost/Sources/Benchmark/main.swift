// MARK: - Benchmark: Inlinability Cost
// Purpose: Measure per-init overhead of a non-@inlinable wrapper vs an
//          @inlinable wrapper when called from a cross-module consumer.
//
// Hypothesis: removing @inlinable from a one-line ~Copyable/~Escapable
//             wrapper init (as the Ownership.Borrow / Property.View
//             workaround does for the Swift 6.3.1/6.4-dev miscompile) adds
//             a per-call cost bounded by the cross-module function-call
//             overhead (~3–6 ns on modern CPUs).
//
// Toolchain: Swift 6.3 / 6.4-dev
// Platform: macOS (.v26), Apple Silicon
// Build:    swift build -c release
// Run:      swift run -c release
// Date:     2026-04-24
//
// Result: CONFIRMED — realistic hot-path overhead ≈ 3.5 ns per non-inlined
//         wrapper construction.
//
//         Loop B (opaque write + wrapper + load):
//           Direct (no wrapper):              0.806 ns/iter
//           InlineWrapper    (@inlinable):    0.808 ns/iter  (fully elided)
//           OutOfLineWrapper (non-@inlinable): 4.354 ns/iter
//           @inlinable-loss cost:             ≈ 3.5 ns/iter
//
//         Interpretation: ~12 CPU cycles at 3.5 GHz. Firmly in the "function
//         call overhead" regime, which matches expectation — removing
//         @inlinable replaces an inlined body with a cross-module call.
//         Absolute overhead is bounded; relative overhead depends on how
//         much real work surrounds the Property.View construction. For
//         typical hot paths with ~50–100 ns of surrounding work per view,
//         the workaround costs <5% relative.
//
// Caveat: benchmarked the `inout` wrapper shape, not `borrowing`. The
//         borrowing shape with @inlinable crashes per the compiler bug
//         (V1 in borrow-pointer-storage-release-miscompile). The inlined-
//         vs-non-inlined call-boundary cost should be architecturally
//         identical between the two shapes — the measurement isolates the
//         calling-convention overhead, which is independent of the body's
//         Value-ownership semantics.

import Wrappers

struct Target: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}

// MARK: - Loop A: "DCE-friendly" — wrapper constructed but pointer never loaded
//                 Shows ceiling: how much the optimizer can eliminate when the
//                 wrapper body is transparent.

@inline(never)
func loopInline_noload(_ target: inout Target, _ n: Int) -> Int {
    var acc: Int = 0
    for _ in 0..<n {
        let w = InlineWrapper(&target)
        acc &+= Int(bitPattern: UInt(bitPattern: w.opaque))
    }
    return acc
}

@inline(never)
func loopOutOfLine_noload(_ target: inout Target, _ n: Int) -> Int {
    var acc: Int = 0
    for _ in 0..<n {
        let w = OutOfLineWrapper(&target)
        acc &+= Int(bitPattern: UInt(bitPattern: w.opaque))
    }
    return acc
}

// Opaque writer — @_optimize(none) prevents the optimizer from folding
// the write across iterations.
@_optimize(none)
@inline(never)
func opaqueWrite(_ p: UnsafeMutablePointer<Int>, _ v: Int) {
    p.pointee = v
}

// MARK: - Loop B: "Realistic" — wrapper constructed, pointer dereferenced.
//                 Target mutated opaquely each iteration so the load can't
//                 be constant-folded.

@inline(never)
func loopInline_load(_ target: inout Target, _ n: Int) -> Int {
    var acc: Int = 0
    for i in 0..<n {
        unsafe withUnsafeMutablePointer(to: &target.x) { opaqueWrite($0, i &* 7 &+ 13) }
        let w = InlineWrapper(&target)
        acc &+= unsafe w.opaque.load(as: Int.self)
    }
    return acc
}

@inline(never)
func loopOutOfLine_load(_ target: inout Target, _ n: Int) -> Int {
    var acc: Int = 0
    for i in 0..<n {
        unsafe withUnsafeMutablePointer(to: &target.x) { opaqueWrite($0, i &* 7 &+ 13) }
        let w = OutOfLineWrapper(&target)
        acc &+= unsafe w.opaque.load(as: Int.self)
    }
    return acc
}

// MARK: - Loop C: "Direct" — no wrapper at all
//                 Lower-bound reference: cost of the memory access alone.

@inline(never)
func loopDirect_load(_ target: inout Target, _ n: Int) -> Int {
    var acc: Int = 0
    for i in 0..<n {
        unsafe withUnsafeMutablePointer(to: &target.x) { opaqueWrite($0, i &* 7 &+ 13) }
        acc &+= target.x
    }
    return acc
}

// MARK: - Formatting

func fmt3(_ d: Double) -> String {
    let t = Int((d * 1000).rounded())
    let whole = t / 1000
    let frac = abs(t % 1000)
    let pad = frac < 10 ? "00" : (frac < 100 ? "0" : "")
    return "\(whole).\(pad)\(frac)"
}

func fmt2(_ d: Double) -> String {
    let t = Int((d * 100).rounded())
    let whole = t / 100
    let frac = abs(t % 100)
    let pad = frac < 10 ? "0" : ""
    return "\(whole).\(pad)\(frac)"
}

func nanos(_ d: Duration, iterations n: Int) -> Double {
    let c = d.components
    let total = Double(c.seconds) * 1e9 + Double(c.attoseconds) / 1e9
    return total / Double(n)
}

// MARK: - Run

let N = 500_000_000
let clock = ContinuousClock()

// Warmup
var target = Target(42)
_ = loopInline_noload(&target, 1_000_000)
_ = loopOutOfLine_noload(&target, 1_000_000)
_ = loopInline_load(&target, 1_000_000)
_ = loopOutOfLine_load(&target, 1_000_000)
_ = loopDirect_load(&target, 1_000_000)

print("N = \(N) iterations per measurement")
print()

// Measure each twice (alternating) and average
let tIN1 = clock.measure { _ = loopInline_noload(&target, N) }
let tIN2 = clock.measure { _ = loopInline_noload(&target, N) }

let tON1 = clock.measure { _ = loopOutOfLine_noload(&target, N) }
let tON2 = clock.measure { _ = loopOutOfLine_noload(&target, N) }

let tIL1 = clock.measure { _ = loopInline_load(&target, N) }
let tIL2 = clock.measure { _ = loopInline_load(&target, N) }

let tOL1 = clock.measure { _ = loopOutOfLine_load(&target, N) }
let tOL2 = clock.measure { _ = loopOutOfLine_load(&target, N) }

let tD1 = clock.measure { _ = loopDirect_load(&target, N) }
let tD2 = clock.measure { _ = loopDirect_load(&target, N) }

func avg(_ a: Duration, _ b: Duration) -> Double {
    (nanos(a, iterations: N) + nanos(b, iterations: N)) / 2.0
}

let iN = avg(tIN1, tIN2)
let oN = avg(tON1, tON2)
let iL = avg(tIL1, tIL2)
let oL = avg(tOL1, tOL2)
let dL = avg(tD1, tD2)

print("Loop A — no load (DCE-friendly ceiling):")
print("  InlineWrapper      (@inlinable):       \(fmt3(iN))  ns/iter")
print("  OutOfLineWrapper   (non-@inlinable):   \(fmt3(oN))  ns/iter")
print("  delta:                                  \(fmt3(oN - iN))  ns/iter  (\(fmt2(oN / max(iN, 0.001)))x)")
print()
print("Loop B — with load (realistic hot path):")
print("  Direct             (no wrapper):       \(fmt3(dL))  ns/iter")
print("  InlineWrapper      (@inlinable):       \(fmt3(iL))  ns/iter")
print("  OutOfLineWrapper   (non-@inlinable):   \(fmt3(oL))  ns/iter")
print("  inlined overhead vs direct:             \(fmt3(iL - dL))  ns/iter")
print("  non-inlined overhead vs direct:         \(fmt3(oL - dL))  ns/iter")
print("  @inlinable loss cost (non-inl - inl):   \(fmt3(oL - iL))  ns/iter")
print()
print("Raw runs:")
print("  inline-noload  A: \(fmt3(nanos(tIN1, iterations: N))), B: \(fmt3(nanos(tIN2, iterations: N)))")
print("  outline-noload A: \(fmt3(nanos(tON1, iterations: N))), B: \(fmt3(nanos(tON2, iterations: N)))")
print("  inline-load    A: \(fmt3(nanos(tIL1, iterations: N))), B: \(fmt3(nanos(tIL2, iterations: N)))")
print("  outline-load   A: \(fmt3(nanos(tOL1, iterations: N))), B: \(fmt3(nanos(tOL2, iterations: N)))")
print("  direct-load    A: \(fmt3(nanos(tD1, iterations: N))), B: \(fmt3(nanos(tD2, iterations: N)))")
