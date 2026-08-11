// MARK: - Ownership.Inout.value Accessor Copyability Split (V12)
//
// Purpose: Verify the V12 accessor split shape in isolation —
//   `Ownership.Inout<Value>.value` exposes `get + nonmutating _modify`
//   when `Value: Copyable` and `_read + nonmutating _modify` when
//   `Value: ~Copyable`. Both paths route through the shared pointer
//   for CoW-preserving nested method-call mutations.
//
// Hypothesis: The split compiles cleanly on Swift 6.3.1, `_modify`
// fires for nested method-call mutations (not just assignment), and
// the `Copyable` `get` path releases pure reads from the coroutine
// lifetime chain that `_read` imposes.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: CONFIRMED
//
// Result: CONFIRMED — all four assertions below pass under Swift 6.3.1
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         with the V12 shape in swift-ownership-primitives.
//
// Build succeeded; runtime output:
//   V1 Copyable-Value read + mutate: count = 2
//   V2 ~Copyable-Value read + mutate: payload = 7
//   V3 Nested method-call mutation preserves writeback: values = [1, 2]
//   V4 Pure-read `get` path returns a copy: isolated = 100
//
// Provenance: HANDOFF-property-view-ownership-inout-lifetime-chain.md
//             V12 fix committed to swift-ownership-primitives as
//             Ownership.Inout.value split-by-copyability.

import Ownership_Primitives

// MARK: - V1: Copyable `Value` takes get + _modify

struct Counter {
    var count: Int
}

func testCopyableRead() {
    var counter = Counter(count: 0)
    let ref = Ownership.Inout(mutating: &counter)
    // `get` path: returns a copy; no compound lifetime dependency
    let current = ref.value.count
    // `nonmutating _modify` path: in-place write through the pointer
    ref.value = Counter(count: current + 2)
    precondition(counter.count == 2, "Copyable-Value mutation must reach the source")
    print("V1 Copyable-Value read + mutate: count = \(counter.count)")
}
testCopyableRead()

// MARK: - V2: ~Copyable `Value` takes _read + _modify

struct Payload: ~Copyable {
    var value: Int
}

func testNoncopyableRead() {
    var payload = Payload(value: 5)
    let ref = Ownership.Inout(mutating: &payload)
    // `_read` path: coroutine-yielded borrow
    let snapshot = ref.value.value
    // `nonmutating _modify` path: in-place write
    ref.value = Payload(value: snapshot + 2)
    precondition(payload.value == 7, "~Copyable-Value mutation must reach the source")
    print("V2 ~Copyable-Value read + mutate: payload = \(payload.value)")
}
testNoncopyableRead()

// MARK: - V3: _modify preserves CoW on nested method-call mutations

struct Holder {
    var values: [Int] = []

    mutating func append(_ x: Int) {
        values.append(x)
    }
}

func testNestedMethodMutation() {
    var holder = Holder()
    let ref = Ownership.Inout(mutating: &holder)
    // Nested method-call mutation: .append(_:) is mutating on Holder.
    // The `Copyable`-Value path uses get + _modify. A get + set split
    // would have broken this (set writeback does not fire for nested
    // method-call mutations — the mutation lives on the throwaway copy
    // returned by get). _modify routes through the pointer, so the
    // append reaches &holder.
    ref.value.append(1)
    ref.value.append(2)
    precondition(holder.values == [1, 2], "Nested method mutation must write through")
    print("V3 Nested method-call mutation preserves writeback: values = \(holder.values)")
}
testNestedMethodMutation()

// MARK: - V4: `get` path releases pure-read from the coroutine lifetime chain

struct Box {
    let tag: Int
}

func testPureRead() {
    var box = Box(tag: 100)
    let ref = Ownership.Inout(mutating: &box)
    // A pure read through the `get` path yields a Copyable `Box` by
    // copy. No compound lifetime dependency — the returned value is
    // Escapable and may outlive `ref`. In chains passing through
    // multiple `@_lifetime(borrow self)` accessors (the property-
    // view / buffer-ring case), this is the shape that avoids the
    // "lifetime-dependent value escapes its scope" compiler error.
    let isolated: Box = ref.value
    precondition(isolated.tag == 100)
    print("V4 Pure-read `get` path returns a copy: isolated = \(isolated.tag)")
}
testPureRead()
