// MARK: - Property.Consuming State allocation benchmark
//
// Purpose: Measure the runtime cost difference between the two candidate
//   designs for Property.Consuming.State:
//     - Option A: class State + @unchecked Sendable (current production
//       after commit a54cab8)
//     - Option C: struct State: ~Copyable + plain Sendable (proposed
//       redesign; blocked in release by EarlyPerfInliner crash when used
//       via _read/_modify accessors — see
//       Experiments/property-consuming-value-state)
//
//   The direct-construction path (no accessor) avoids the inliner crash,
//   so we can benchmark both variants cleanly in release mode.
//
// Hypothesis: Option C eliminates N heap allocations (one per class State),
//   so the construct+consume loop should be meaningfully faster in release.
//   If the win is small or absent, Option C's @_optimize(none) workaround
//   requirement on accessor sites is not justified.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102), Xcode 26.4.1
// Platform: macOS 26.0 (arm64)
//
// Status: REFUTED (as of Swift 6.3.1)
// Result: REFUTED — no meaningful performance difference between class-State
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   and struct-State in the direct-construction path. Measured across 4
//   trial batches (best-of-10 each, N=10M):
//     Trial 1: A=40.4 ms  / C=37.7 ms  → C faster by  6.7%
//     Trial 2: A=43.3 ms  / C=51.6 ms  → A faster by 19.2%
//     Trial 3: A=47.7 ms  / C=44.6 ms  → C faster by  6.5%
//     Trial 4: A=43.5 ms  / C=39.1 ms  → C faster by 10.1%
//   Results within measurement noise. The theoretical heap-allocation
//   elimination of Option C is not realized in practice — Swift's escape
//   analysis stack-promotes the class instance in this tight loop, so both
//   variants pay roughly the same per-iteration cost.
//
//   Implication: Option C has no performance justification to offset its
//   release-mode SIL inliner crash blocker (see
//   Experiments/property-consuming-value-state). Production adoption not
//   justified on perf grounds.
//
// Date: 2026-04-21

import Foundation  // for Date/TimeInterval — benchmark timing only

// MARK: - Shared shape (mirrors Property Primitives Core)

struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Base

    @inlinable
    init(_ base: consuming Base) { self._base = base }
}

extension Property where Base: Copyable {
    struct ConsumingA<Element>: ~Copyable {
        @usableFromInline
        internal let _state: StateA

        @inlinable
        init(_ base: consuming Base) { self._state = StateA(base) }
    }

    struct ConsumingC<Element>: ~Copyable {
        @usableFromInline
        internal var _state: StateC

        @inlinable
        init(_ base: consuming Base) { self._state = StateC(base) }
    }
}

// MARK: - Option A: class-based State (current production)

extension Property.ConsumingA {
    final class StateA {
        @usableFromInline internal var _base: Base?
        @usableFromInline internal var _consumed: Bool

        @inlinable init(_ base: consuming Base) {
            self._base = consume base
            self._consumed = false
        }
    }
}

extension Property.ConsumingA {
    @inlinable
    mutating func consume() -> Base? {
        guard let base = _state._base else { return nil }
        _state._consumed = true
        _state._base = nil
        return base
    }
}

// MARK: - Option C: struct ~Copyable State

extension Property.ConsumingC {
    struct StateC: ~Copyable {
        @usableFromInline internal var _base: Base?
        @usableFromInline internal var _consumed: Bool

        @inlinable init(_ base: consuming Base) {
            self._base = base
            self._consumed = false
        }
    }
}

extension Property.ConsumingC {
    @inlinable
    mutating func consume() -> Base? {
        guard let base = _state._base else { return nil }
        _state._consumed = true
        _state._base = nil
        return base
    }
}

// MARK: - Benchmark harness

enum Phantom {}

// Defeat constant folding — the compiler can see through @inline(never)
// if inputs are literal constants. Pass iteration count via argv and
// feed the per-iteration result through a pointer-sinking blackhole.

@inline(never)
@_optimize(none)
func blackhole<T>(_ value: T) {
    withUnsafePointer(to: value) { _ = $0 }
}

@inline(never)
func benchmarkOptionA(iterations: Int, seed: Int) -> Int {
    var acc = seed
    for i in 0..<iterations {
        var c = Property<Phantom, Int>.ConsumingA<Int>(i &+ seed)
        if let taken = c.consume() { acc &+= taken }
        blackhole(acc)
    }
    return acc
}

@inline(never)
func benchmarkOptionC(iterations: Int, seed: Int) -> Int {
    var acc = seed
    for i in 0..<iterations {
        var c = Property<Phantom, Int>.ConsumingC<Int>(i &+ seed)
        if let taken = c.consume() { acc &+= taken }
        blackhole(acc)
    }
    return acc
}

func time(_ label: String, _ body: () -> Int) {
    let trials = 10
    var bestNanos: UInt64 = .max
    var lastResult = 0
    for _ in 0..<trials {
        let start = DispatchTime.now().uptimeNanoseconds
        lastResult = body()
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        if elapsed < bestNanos { bestNanos = elapsed }
    }
    let ms = Double(bestNanos) / 1_000_000
    print("\(label): best \(String(format: "%.3f", ms)) ms (check: \(lastResult))")
}

let argN = Int(CommandLine.arguments.dropFirst().first ?? "") ?? 10_000_000
let seed = Int(DispatchTime.now().uptimeNanoseconds & 0xFF)

print("Iterations per trial: \(argN), best-of-10 trials reported. Seed: \(seed)")
print("")

time("Option A (class State)  ") { benchmarkOptionA(iterations: argN, seed: seed) }
time("Option C (struct State) ") { benchmarkOptionC(iterations: argN, seed: seed) }
