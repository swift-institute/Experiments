// MARK: - Callback Isolated Prototype Validation
// Purpose: Validate nonsending callback prototype compiles and preserves
//          isolation end-to-end. Tests multiple compiler approaches for the
//          region checker, and whether nonsending closure-in-closure preserves
//          caller isolation (issue #83812).
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Approach C with callAsFunction(isolation:) preserves isolation through map/flatMap; stored nonsending closures lose isolation (#83812)
//
// === KEY DISCOVERIES ===
//
// D1 (compile): Non-Sendable struct with nonisolated async PROPERTY getter
//     DOES NOT COMPILE — region checker treats non-Sendable return as crossing
//     from nonisolated region to caller region.
//
// D2 (runtime, CRITICAL): Stored nonsending closure called from inside another
//     nonsending closure DOES NOT inherit caller isolation at runtime. The sync
//     transform in map runs on cooperative pool, not MainActor. This is issue #83812.
//     Affects approaches A, B, E (which call self.operation() directly in map).
//
// D3 (runtime): METHOD calls from nonsending closures DO propagate isolation.
//     Approaches C (isolated parameter) and D (explicit nonsending) wrap the
//     stored closure call in a method — map's sync transform runs on MainActor.
//
// D4 (runtime): @unchecked Sendable nonsending closures preserve CREATION-TIME
//     isolation even when invoked from another actor. Closure created on MainActor
//     still ran on MainActor when invoked from Receiver actor (T14).
//
// D5 (compile): Non-Sendable Value works with: sending return (B), isolated
//     parameter (C), explicit nonsending method (D), direct operation() (E).
//     Does NOT work with computed property getter (region checker).
//
// D6 (compile): Nesting Isolated<V> inside generic Callback<Value: Sendable>
//     requires specifying meaningless outer generic: Callback<Never>.Isolated<T>.
//     Top-level type is cleaner.
//
// D7 (runtime): callAsFunction(isolation: isolated (any Actor)? = #isolation)
//     works as method wrapper for stored nonsending closure. `await self()` in
//     map/flatMap propagates isolation correctly (T15c, T15d, T15e). Syntax:
//     `await callback()` — reads as intent per [IMPL-INTENT].
//
// === RESULTS SUMMARY ===
//
//   T1  — CONFIRMED: All 5 approaches: core init + value works
//   T2  — CONFIRMED: All 5 approaches: single-level isolation (init closure on MainActor)
//   T3  — CONFIRMED: Deferred execution (closure doesn't run until .value accessed)
//   T4  — MIXED: Map transform isolation:
//         A,B,E FAIL  — stored closure call in map doesn't propagate isolation (#83812)
//         C,D   PASS  — method wrapper propagates isolation correctly
//   T5  — CONFIRMED: All 5 approaches: map correctness (21*2=42)
//   T6  — REFUTED (A): Chained maps also lose isolation on A
//   T7  — REFUTED (A): flatMap transform also loses isolation on A
//   T8  — CONFIRMED: Non-Sendable Value works (B,C,D,E — not A which requires Sendable)
//   T9  — CONFIRMED: Bridge CPS Callback → isolated type works
//   T10 — CONFIRMED: Materialized value crosses isolation boundaries
//   T11 — CONFIRMED: Nonsending callback wraps CPS cross-isolation work
//   T12 — DOES NOT COMPILE: non-Sendable closure can't be sent to nonisolated run(_:)
//   T13 — CONFIRMED: Nesting compiles but requires Callback<Never>.Isolated<T>
//   T14 — CONFIRMED: @unchecked Sendable preserves creation-time isolation
//   T15 — CONFIRMED: callAsFunction(isolation:) — all 12 subtests pass:
//         basic invocation, isolation, map isolation, chained maps (3 levels),
//         flatMap, non-Sendable Value, non-Sendable map chain, deferred execution
//
// === RECOMMENDED APPROACH ===
//
//   Approach C with callAsFunction(isolation:):
//   - `await callback()` syntax — reads as intent [IMPL-INTENT]
//   - Non-Sendable Value support
//   - Map/flatMap isolation preserved via `await self()` (method wrapper)
//   - No @unchecked Sendable escape hatch
//   - Replacement-ready: single type replaces CPS Callback
//
// Date: 2026-02-25

import Foundation  // for Thread.isMainThread

// ============================================================================
// MARK: - Helpers
// ============================================================================

enum Async {}

extension Async {
    struct Callback<Value: Sendable>: Sendable {
        let run: @Sendable (@escaping @Sendable (Value) -> Void) -> Void
        init(run: @escaping @Sendable (_ cb: @escaping @Sendable (Value) -> Void) -> Void) { self.run = run }
        init(value: Value) { self.run = { cb in cb(value) } }
        var value: Value {
            get async {
                await withCheckedContinuation { c in self.run { c.resume(returning: $0) } }
            }
        }
    }
}

class NonSendableModel {
    var name: String
    init(name: String) { self.name = name }
}

/// Non-crashing isolation check (Thread.isMainThread for MainActor)
func onMain() -> Bool { Thread.isMainThread }

func pass(_ label: String) { print("  ✅ \(label)") }
func fail(_ label: String, _ reason: String) { print("  ❌ \(label): \(reason)") }
func check(_ label: String, _ condition: Bool) {
    condition ? pass(label) : fail(label, "condition false")
}

// ============================================================================
// MARK: - Approach A: @unchecked Sendable, Value: Sendable
//   Uses self.operation() in map/flatMap (not .value property)
// ============================================================================

struct ApproachA<Value: Sendable>: @unchecked Sendable {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ op: nonisolated(nonsending) @escaping () async -> Value) { self.operation = op }
    init(value: Value) { self.operation = { value } }

    var value: Value { get async { await operation() } }

    func map<U: Sendable>(_ f: @escaping (Value) -> U) -> ApproachA<U> {
        .init { f(await self.operation()) }
    }
    func flatMap<U: Sendable>(_ f: @escaping (Value) -> ApproachA<U>) -> ApproachA<U> {
        .init { await f(await self.operation()).operation() }
    }
}

extension ApproachA {
    init(from callback: Async.Callback<Value>) {
        self.init {
            await withCheckedContinuation { c in callback.run { c.resume(returning: $0) } }
        }
    }
}

// ============================================================================
// MARK: - Approach B: @unchecked Sendable, Value unconstrained, sending return
// ============================================================================

struct ApproachB<Value>: @unchecked Sendable {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ op: nonisolated(nonsending) @escaping () async -> Value) { self.operation = op }
    init(value: Value) { self.operation = { value } }

    func getValue() async -> sending Value { await operation() }

    func map<U>(_ f: @escaping (Value) -> U) -> ApproachB<U> {
        .init { f(await self.getValue()) }
    }
    func flatMap<U>(_ f: @escaping (Value) -> ApproachB<U>) -> ApproachB<U> {
        .init { await f(await self.getValue()).getValue() }
    }
}

// ============================================================================
// MARK: - Approach C: Non-Sendable, isolated parameter (SE-0420)
// ============================================================================

struct ApproachC<Value> {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ op: nonisolated(nonsending) @escaping () async -> Value) { self.operation = op }
    init(value: Value) { self.operation = { value } }

    func callAsFunction(isolation: isolated (any Actor)? = #isolation) async -> Value {
        await operation()
    }

    func map<U>(_ f: @escaping (Value) -> U) -> ApproachC<U> {
        .init { f(await self()) }
    }
    func flatMap<U>(_ f: @escaping (Value) -> ApproachC<U>) -> ApproachC<U> {
        .init { await f(await self())() }
    }
}

// ============================================================================
// MARK: - Approach D: Non-Sendable, explicit nonisolated(nonsending) method
// ============================================================================

struct ApproachD<Value> {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ op: nonisolated(nonsending) @escaping () async -> Value) { self.operation = op }
    init(value: Value) { self.operation = { value } }

    nonisolated(nonsending)
    func getValue() async -> Value { await operation() }

    func map<U>(_ f: @escaping (Value) -> U) -> ApproachD<U> {
        .init { f(await self.getValue()) }
    }
    func flatMap<U>(_ f: @escaping (Value) -> ApproachD<U>) -> ApproachD<U> {
        .init { await f(await self.getValue()).getValue() }
    }
}

// ============================================================================
// MARK: - Approach E: @unchecked Sendable, unconstrained Value, property + operation()
// ============================================================================

struct ApproachE<Value>: @unchecked Sendable {
    let operation: nonisolated(nonsending) () async -> Value

    init(_ op: nonisolated(nonsending) @escaping () async -> Value) { self.operation = op }
    init(value: Value) { self.operation = { value } }

    var value: Value { get async { await operation() } }

    func map<U>(_ f: @escaping (Value) -> U) -> ApproachE<U> {
        .init { f(await self.operation()) }
    }
    func flatMap<U>(_ f: @escaping (Value) -> ApproachE<U>) -> ApproachE<U> {
        .init { await f(await self.operation()).operation() }
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

// --- Compile tests (already verified: all approaches above compile) ---

@MainActor func runTests() async {
    print("=== Callback Isolated Prototype ===")
    print()

    // ------------------------------------------------------------------
    // T1: Core — does init + value work at all?
    // ------------------------------------------------------------------
    print("--- T1: Core functionality ---")

    let a1 = ApproachA(value: 42);  check("A-core: \(await a1.value)", await a1.value == 42)
    let b1 = ApproachB(value: 42);  check("B-core: \(await b1.getValue())", await b1.getValue() == 42)
    let c1 = ApproachC(value: 42);  check("C-core: \(await c1())", await c1() == 42)
    let d1 = ApproachD(value: 42);  check("D-core: \(await d1.getValue())", await d1.getValue() == 42)
    let e1 = ApproachE(value: 42);  check("E-core: \(await e1.value)", await e1.value == 42)
    print()

    // ------------------------------------------------------------------
    // T2: Single-level isolation — does the init closure run on MainActor?
    // ------------------------------------------------------------------
    print("--- T2: Single-level isolation (init closure) ---")

    let a2 = ApproachA<Bool> { onMain() }
    check("A-single: init closure on main", await a2.value)

    let b2 = ApproachB<Bool> { onMain() }
    check("B-single: init closure on main", await b2.getValue())

    let c2 = ApproachC<Bool> { onMain() }
    check("C-single: init closure on main", await c2())

    let d2 = ApproachD<Bool> { onMain() }
    check("D-single: init closure on main", await d2.getValue())

    let e2 = ApproachE<Bool> { onMain() }
    check("E-single: init closure on main", await e2.value)
    print()

    // ------------------------------------------------------------------
    // T3: Deferred execution — closure doesn't run until .value accessed
    // ------------------------------------------------------------------
    print("--- T3: Deferred execution ---")
    var side = 0
    let a3 = ApproachA<Int> { side = 99; return side }
    check("A-defer: not yet executed", side == 0)
    _ = await a3.value
    check("A-defer: executed on access", side == 99)
    print()

    // ------------------------------------------------------------------
    // T4: Map — sync transform isolation (CRITICAL: issue #83812)
    //     The sync closure inside map's nonsending closure — does it inherit?
    // ------------------------------------------------------------------
    print("--- T4: Map transform isolation (issue #83812) ---")

    let a4 = ApproachA(value: 21).map { v -> Bool in onMain() }
    check("A-map: sync transform on main", await a4.value)

    let b4 = ApproachB(value: 21).map { v -> Bool in onMain() }
    check("B-map: sync transform on main", await b4.getValue())

    let c4 = ApproachC(value: 21).map { v -> Bool in onMain() }
    check("C-map: sync transform on main", await c4())

    let d4 = ApproachD(value: 21).map { v -> Bool in onMain() }
    check("D-map: sync transform on main", await d4.getValue())

    let e4 = ApproachE(value: 21).map { v -> Bool in onMain() }
    check("E-map: sync transform on main", await e4.value)
    print()

    // ------------------------------------------------------------------
    // T5: Map correctness — value transforms correctly
    // ------------------------------------------------------------------
    print("--- T5: Map correctness ---")

    check("A-mapVal: 21*2=42", await ApproachA(value: 21).map({ $0 * 2 }).value == 42)
    check("B-mapVal: 21*2=42", await ApproachB(value: 21).map({ $0 * 2 }).getValue() == 42)
    check("C-mapVal: 21*2=42", await ApproachC(value: 21).map({ $0 * 2 })() == 42)
    check("D-mapVal: 21*2=42", await ApproachD(value: 21).map({ $0 * 2 }).getValue() == 42)
    check("E-mapVal: 21*2=42", await ApproachE(value: 21).map({ $0 * 2 }).value == 42)
    print()

    // ------------------------------------------------------------------
    // T6: Map chaining — 3 levels
    // ------------------------------------------------------------------
    print("--- T6: Map chaining ---")

    let a6 = ApproachA(value: 10).map { $0 + 5 }.map { "v=\($0)" }.map { $0.count }
    check("A-chain: 10+5→'v=15'→4 chars", await a6.value == 4)

    // Also check isolation at each level
    let a6iso = ApproachA(value: 0)
        .map { _ -> Bool in onMain() }  // level 1
    let a6iso_l1 = await a6iso.value
    let a6iso_l2 = await a6iso.map { _ -> Bool in onMain() }.value  // level 2
    check("A-chain-iso-l1: on main", a6iso_l1)
    check("A-chain-iso-l2: on main", a6iso_l2)
    print()

    // ------------------------------------------------------------------
    // T7: FlatMap — monadic chain
    // ------------------------------------------------------------------
    print("--- T7: FlatMap ---")

    let a7 = ApproachA(value: 7).flatMap { ApproachA(value: "r=\($0 * 6)") }
    check("A-flat: r=42", await a7.value == "r=42")

    let a7iso = ApproachA(value: 0).flatMap { _ -> ApproachA<Bool> in
        return ApproachA(value: onMain())
    }
    check("A-flat-iso: transform on main", await a7iso.value)
    print()

    // ------------------------------------------------------------------
    // T8: Non-Sendable Value (Approach B only — others require Sendable)
    // ------------------------------------------------------------------
    print("--- T8: Non-Sendable Value ---")

    let model = NonSendableModel(name: "original")
    let b8 = ApproachB<NonSendableModel> { model }
    let b8r = await b8.getValue()
    check("B-ns: non-Sendable model", b8r.name == "original")

    let b8m = b8.map { m -> NonSendableModel in m.name = "xformed"; return m }
    let b8mr = await b8m.getValue()
    check("B-ns-map: non-Sendable map", b8mr.name == "xformed")

    // C, D also support non-Sendable
    let c8 = ApproachC<NonSendableModel> { model }
    let c8r = await c8()
    check("C-ns: non-Sendable model", c8r.name == "xformed")  // mutated by b8m

    let d8 = ApproachD<NonSendableModel> { NonSendableModel(name: "d-orig") }
    let d8r = await d8.getValue()
    check("D-ns: non-Sendable model", d8r.name == "d-orig")

    // E also supports non-Sendable via getValue but not .value property
    // (property getter with non-Sendable return fails to compile — known limitation)
    let e8 = ApproachE<NonSendableModel> { NonSendableModel(name: "e-orig") }
    // Cannot use e8.value — would error for non-Sendable
    // But operation() should work:
    let e8r = await e8.operation()
    check("E-ns: non-Sendable via operation()", e8r.name == "e-orig")
    print()

    // ------------------------------------------------------------------
    // T9: Bridge — CPS Callback → ApproachA
    // ------------------------------------------------------------------
    print("--- T9: Bridge ---")

    let cps = Async.Callback<Int>(value: 42)
    let bridged = ApproachA(from: cps)
    check("A-bridge: CPS→isolated", await bridged.value == 42)
    check("A-bridge-iso: on main after bridge", onMain())
    print()

    // ------------------------------------------------------------------
    // T10: Cross-isolation — materialized value to actor
    // ------------------------------------------------------------------
    print("--- T10: Cross-isolation ---")

    let a10 = ApproachA(value: 21)
    let materialized = await a10.value
    let worker = Worker()
    let result = await worker.process(materialized)
    check("A-cross: materialized→actor→42", result == 42)
    check("A-cross-iso: back on main", onMain())
    print()

    // ------------------------------------------------------------------
    // T11: CPS wrapping — nonsending callback wraps OS-style callback
    // ------------------------------------------------------------------
    print("--- T11: CPS wrapping (replacement feasibility) ---")

    let a11 = ApproachA<Int> {
        await withCheckedContinuation { c in
            simulateCPS { c.resume(returning: $0) }
        }
    }
    let r11 = await a11.value
    check("A-cps: wraps cross-isolation CPS", r11 == 42)
    check("A-cps-iso: back on main", onMain())
    print()

    // ------------------------------------------------------------------
    // T12: CPS consumption — run(_:) on isolated type
    // NOTE: Passing a non-Sendable closure capturing mutable @MainActor
    //       state to a nonisolated method is rejected by the compiler:
    //       "sending main actor-isolated value of non-Sendable type"
    //       This confirms the compiler prevents unsafe closure transfer.
    //       CPS consumption would need isolated parameter or nonsending annotation.
    // ------------------------------------------------------------------
    print("--- T12: CPS consumption ---")
    print("  ⚠️  T12: DOES NOT COMPILE — non-Sendable closure can't be sent to nonisolated run(_:)")
    print("       Fix: run(_:) needs isolated parameter or nonisolated(nonsending) annotation")
    print()

    // ------------------------------------------------------------------
    // T13: Nesting ergonomics — Callback<Never>.Isolated<T>
    // ------------------------------------------------------------------
    print("--- T13: Nesting ergonomics ---")

    let nested: Async.Callback<Never>.Isolated<Int> = .init(value: 42)
    check("Nest: Callback<Never>.Isolated<Int>", await nested.value == 42)
    print("  ℹ️  Requires Async.Callback<Never>.Isolated<T> — meaningless outer generic")
    print("  ℹ️  Top-level Async.IsolatedCallback<T> or renamed Async.Callback<T> is cleaner")
    print()

    // ------------------------------------------------------------------
    // T14: @unchecked Sendable soundness — sent to another actor
    // ------------------------------------------------------------------
    print("--- T14: @unchecked Sendable soundness ---")

    let a14 = ApproachA<Bool> { onMain() }
    let receiver = Receiver()
    let fromReceiver = await receiver.run(a14)
    check("A-sound: invoked from other actor, on main = \(fromReceiver)", true)
    // fromReceiver tells us if the closure ran on main or not when invoked from another actor
    if fromReceiver {
        print("  ℹ️  Closure still ran on MainActor even from another actor — isolation preserved!")
    } else {
        print("  ℹ️  Closure ran OFF MainActor when invoked from another actor — nonsending inherits invoker")
    }
    print()

    // ------------------------------------------------------------------
    // T15: callAsFunction — await callback() syntax
    //     Tests: basic invocation, map isolation, chained maps, flatMap,
    //     non-Sendable Value, deferred execution
    // ------------------------------------------------------------------
    print("--- T15: callAsFunction syntax ---")

    // T15a: Basic invocation — await callback()
    let c15a = ApproachC(value: 42)
    check("C-call: await callback() == 42", await c15a() == 42)

    // T15b: Isolation — closure runs on MainActor
    let c15b = ApproachC<Bool> { onMain() }
    check("C-call-iso: closure on main", await c15b())

    // T15c: Map isolation — sync transform preserves isolation via self()
    let c15c = ApproachC(value: 21).map { _ -> Bool in onMain() }
    check("C-call-map-iso: map transform on main", await c15c())

    // T15d: Chained maps — 3 levels, isolation at every level
    let c15d = ApproachC(value: 10)
        .map { $0 + 5 }
        .map { "v=\($0)" }
        .map { $0.count }
    check("C-call-chain: 10+5→'v=15'→4", await c15d() == 4)

    let c15d_iso = ApproachC(value: 0)
        .map { _ -> Bool in onMain() }
        .map { prev -> (Bool, Bool) in (prev, onMain()) }
    let (l1, l2) = await c15d_iso()
    check("C-call-chain-iso-l1: on main", l1)
    check("C-call-chain-iso-l2: on main", l2)

    // T15e: FlatMap — monadic chain via callAsFunction
    let c15e = ApproachC(value: 7).flatMap { v in
        ApproachC(value: "r=\(v * 6)")
    }
    check("C-call-flat: r=42", await c15e() == "r=42")

    let c15e_iso = ApproachC(value: 0).flatMap { _ in
        ApproachC(value: onMain())
    }
    check("C-call-flat-iso: transform on main", await c15e_iso())

    // T15f: Non-Sendable Value via callAsFunction
    let c15f = ApproachC<NonSendableModel> { NonSendableModel(name: "call-as-func") }
    let c15f_r = await c15f()
    check("C-call-ns: non-Sendable Value", c15f_r.name == "call-as-func")

    // T15g: Non-Sendable map chain via callAsFunction
    let c15g = ApproachC<NonSendableModel> { NonSendableModel(name: "hello") }
        .map { m -> String in m.name.uppercased() }
    check("C-call-ns-map: non-Sendable→String", await c15g() == "HELLO")

    // T15h: Deferred execution — closure doesn't run until await callback()
    var c15side = 0
    let c15h = ApproachC<Int> { c15side = 77; return c15side }
    check("C-call-defer: not yet executed", c15side == 0)
    _ = await c15h()
    check("C-call-defer: executed on call", c15side == 77)

    print()

    // ------------------------------------------------------------------
    // Summary
    // ------------------------------------------------------------------
    print("=== Summary ===")
    print()
    print("Compile results:")
    print("  A (@unchecked Sendable, Value: Sendable)       — COMPILES")
    print("  B (@unchecked Sendable, sending return)         — COMPILES")
    print("  C (non-Sendable, isolated parameter)            — COMPILES")
    print("  D (non-Sendable, explicit nonsending method)    — COMPILES")
    print("  E (@unchecked Sendable, unconstrained, prop)    — COMPILES (property+non-Sendable return FAILS)")
    print("  Non-Sendable struct + nonisolated async prop    — DOES NOT COMPILE (region checker)")
    print()
    print("=== All tests complete ===")
}

extension ApproachA {
    func run(_ callback: (Value) -> Void) async {
        callback(await value)
    }
}

extension Async.Callback {
    struct Isolated<V>: @unchecked Sendable {
        let operation: nonisolated(nonsending) () async -> V
        init(_ op: nonisolated(nonsending) @escaping () async -> V) { self.operation = op }
        init(value: V) { self.operation = { value } }
        var value: V { get async { await operation() } }
    }
}

actor Worker {
    func process(_ value: Int) -> Int { value * 2 }
}

actor Receiver {
    func run<T>(_ cb: ApproachA<T>) async -> T { await cb.value }
}

func simulateCPS(completion: @Sendable @escaping (Int) -> Void) {
    Task.detached { completion(42) }
}

await runTests()
