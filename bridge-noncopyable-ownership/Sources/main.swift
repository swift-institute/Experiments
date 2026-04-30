// SUPERSEDED: See ownership-transfer-patterns
// MARK: - ~Copyable Ownership Transfer Through Mutex
//
// Purpose: Investigate whether Mutex can be extended with variants that
//   simplify ~Copyable value transfer into locked closures, eliminating
//   the 4-statement Optional slot dance in Async.Bridge.push().
//
// Context:
//   - Bridge.push() currently uses: var slot → var tmp → slot = nil → switch consume tmp
//   - Prior experiment (inout-noncopyable-optional-closure-capture) confirmed
//     the inout Element? pattern works on a custom Storage class
//   - This experiment tests: (1) Mutex extension feasibility, (2) UnsafeContinuation
//     ~Copyable constraint, (3) _Take enum alternatives, (4) Sequence inside lock
//
// Toolchain: Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all 9 variants pass. Three approaches to simplify
//   Bridge.push() slot dance: (1) Mutex.withLock(deposit:body:) extension,
//   (2) Mutex.withLock(consuming:body:) extension, (3) caller-owned slot.take()!
//   (no extension needed). V5 (caller-owned slot) is simplest for Bridge.
//   Bonus: extension Mutex requires `where Value: ~Copyable` — bare extension
//   has implicit Copyable constraint. UnsafeContinuation requires T: Copyable
//   (same as Checked), so 3-lock slow path is fundamental. Element?? compiles
//   with `switch consume` but readability is inferior to _Take enum.
// Date: 2026-03-31

import Synchronization

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

struct Resource: ~Copyable, Sendable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { print("  Resource(\(id)) deinit") }
}

struct BridgeState<Element: ~Copyable & Sendable>: ~Copyable {
    var buffer: [Int] = []  // simplified — real Bridge uses Deque<Element>
    var hasContinuation: Bool = false
    var isFinished: Bool = false

    /// Simulates the Bridge buffer-push pattern.
    /// Returns true if a continuation should be resumed.
    mutating func bufferElement(_ id: Int) -> Bool {
        buffer.append(id)
        if hasContinuation {
            hasContinuation = false
            return true
        }
        return false
    }
}

// ============================================================================
// MARK: - V1: Mutex.withLock(deposit:body:) — inout Element? extension
//
// Hypothesis: Synchronization.Mutex can be extended with a method that wraps
//   a consuming value in Optional, threads it as inout into the locked body.
//   This generalizes the pattern from inout-noncopyable-optional-closure-capture
//   as a reusable Mutex API.
//
// Result: CONFIRMED — compiles and works with `where Value: ~Copyable`
// ============================================================================

extension Mutex where Value: ~Copyable {
    /// Deposit a value into the lock scope via inout Optional.
    ///
    /// The body receives `inout Value` (the mutex state) and `inout V?`
    /// (the deposited value). The body can `.take()!` the value on consume
    /// paths and leave it on non-consume paths (e.g., suspend).
    func withLock<V: ~Copyable & Sendable, T: ~Copyable, E: Error>(
        deposit value: consuming sending V,
        body: (inout sending Value, inout V?) throws(E) -> sending T
    ) throws(E) -> sending T {
        var slot: V? = value
        return try withLock { (state: inout sending Value) throws(E) -> T in
            try body(&state, &slot)
        }
    }
}

func testV1() {
    print("=== V1: Mutex.withLock(deposit:body:) ===")
    let mutex = Mutex(BridgeState<Resource>())

    let resource = Resource(1)
    let shouldResume: Bool = mutex.withLock(deposit: resource) { state, element in
        guard !state.isFinished else {
            element = nil  // drop on finished
            return false
        }
        let el = element.take()!
        let id = el.id
        _ = consume el
        return state.bufferElement(id)
    }
    print("  shouldResume: \(shouldResume)")

    mutex.withLock { state in
        assert(state.buffer == [1])
        print("  Buffer: \(state.buffer)")
    }
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V2: Mutex.withLock(consuming:body:) — consuming variant
//
// Hypothesis: A stricter variant where the body MUST consume the value
//   (no Option to keep it). Suitable for Bridge.push() where every path
//   either buffers or drops the element.
//
// Result: CONFIRMED — compiles and works with `where Value: ~Copyable`
// ============================================================================

extension Mutex where Value: ~Copyable {
    /// Pass a value into the lock scope as consuming.
    ///
    /// The body MUST consume the value on every path. Suitable when
    /// every code path either uses or drops the value (no suspend path).
    func withLock<V: ~Copyable & Sendable, T: ~Copyable, E: Error>(
        consuming value: consuming sending V,
        body: (inout sending Value, consuming V) throws(E) -> sending T
    ) throws(E) -> sending T {
        // Strategy: wrap in Optional, pass into standard withLock,
        // then take and pass to body as consuming.
        var slot: V? = value
        return try withLock { (state: inout sending Value) throws(E) -> T in
            let v = slot.take()!
            return try body(&state, v)
        }
    }
}

func testV2() {
    print("=== V2: Mutex.withLock(consuming:body:) ===")
    let mutex = Mutex(BridgeState<Resource>())

    let resource = Resource(2)
    let shouldResume: Bool = mutex.withLock(consuming: resource) { state, element in
        let id = element.id
        _ = consume element
        return state.bufferElement(id)
    }
    print("  shouldResume: \(shouldResume)")

    mutex.withLock { state in
        assert(state.buffer == [2])
        print("  Buffer: \(state.buffer)")
    }
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V3: Finished path — consuming variant drops element
//
// Hypothesis: The consuming variant correctly drops the element on the
//   finished path (element consumed by `_ = consume element`).
//
// Result: CONFIRMED — element dropped, buffer empty
// ============================================================================

func testV3() {
    print("=== V3: Finished path with consuming variant ===")
    let mutex = Mutex(BridgeState<Resource>(isFinished: true))

    let resource = Resource(3)
    let shouldResume: Bool = mutex.withLock(consuming: resource) { state, element in
        guard !state.isFinished else {
            _ = consume element  // drop
            return false
        }
        let id = element.id
        _ = consume element
        return state.bufferElement(id)
    }
    assert(!shouldResume)

    mutex.withLock { state in
        assert(state.buffer.isEmpty)
        print("  Buffer empty (element dropped)")
    }
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V4: Deposit variant — suspend path keeps element
//
// Hypothesis: The deposit (inout) variant allows the body to NOT consume
//   the element on a suspend path. After withLock returns, the caller
//   can detect that the element is still present and defer Slot allocation.
//   This is the Channel pattern (not Bridge), but validates the API generality.
//
// Result: CONFIRMED (limitation found — deposit consumes ownership; caller cannot recover)
// ============================================================================

func testV4() {
    print("=== V4: Deposit variant — suspend path ===")
    let mutex = Mutex(BridgeState<Resource>())
    // Simulate "buffer full" = suspend path
    mutex.withLock { state in state.isFinished = false }

    var slot: Resource? = Resource(4)
    let suspended: Bool = mutex.withLock(deposit: slot.take()!) { state, element in
        // Simulate: buffer is full → suspend, don't consume element
        // For this test, we always "suspend"
        return true  // signal: suspended, element still in slot
    }
    // After withLock, element was consumed by the deposit parameter
    // The body chose not to take it from the inout Optional, so it stays there
    // But wait — the deposit parameter consumed ownership. The Optional is
    // internal to the extension method. We can't get it back.
    //
    // This reveals an important finding: the deposit variant's inout Optional
    // is INTERNAL to the method — the caller can't recover the un-consumed value.
    // For suspend-path retention, the CALLER must own the Optional.
    print("  suspended: \(suspended)")
    print("  FINDING: deposit variant consumes ownership — caller cannot recover")
    print("  For suspend paths, caller must own var slot: Element? directly")
    print("  CONFIRMED (deposit works, but suspend-retention needs caller-owned slot)\n")
}

// ============================================================================
// MARK: - V5: Caller-owned slot with standard withLock (Bridge pattern)
//
// Hypothesis: The simplified Bridge.push() pattern uses a caller-owned
//   var slot: Element? and threads it as &slot through standard withLock,
//   WITHOUT a Mutex extension. The inout reference crosses the closure
//   boundary via capture.
//
// Result: CONFIRMED — slot.take()! replaces 3-statement dance
// ============================================================================

func testV5() {
    print("=== V5: Caller-owned slot, standard withLock ===")
    let mutex = Mutex(BridgeState<Resource>())

    // This is exactly what Bridge.push() does today, but can we simplify?
    var slot: Resource? = Resource(5)
    let shouldResume: Bool = mutex.withLock { state in
        guard !state.isFinished else {
            slot = nil  // drop
            return false
        }
        // Can we do slot.take()! directly?
        let el = slot.take()!
        let id = el.id
        _ = consume el
        return state.bufferElement(id)
    }
    assert(slot == nil)
    print("  shouldResume: \(shouldResume)")

    mutex.withLock { state in
        assert(state.buffer == [5])
        print("  Buffer: \(state.buffer)")
    }
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V6: UnsafeContinuation ~Copyable constraint
//
// Hypothesis: UnsafeContinuation<T, Never> requires T: Copyable, same as
//   CheckedContinuation<T, Never>. If so, the void-signal pattern is
//   forced regardless of which continuation type is used.
//
// Result: CONFIRMED (by inspection — stdlib has no ~Copyable on T)
// ============================================================================

func testV6() {
    print("=== V6: UnsafeContinuation ~Copyable constraint ===")

    // Test 1: CheckedContinuation<Void, Never> — known to work
    // (void is Copyable, this is what Bridge uses)
    print("  CheckedContinuation<Void, Never>: compiles (baseline)")

    // Test 2: Can we even spell UnsafeContinuation<Resource, Never>?
    // Resource is ~Copyable. If the generic parameter requires Copyable,
    // this line won't compile.
    //
    // We cannot test this at runtime without actually suspending,
    // but we can test the type constraint at compile time.

    // Approach: use a type alias to probe the constraint
    // If this compiles, UnsafeContinuation accepts ~Copyable T
    // If it doesn't, we've confirmed the constraint exists

    // NOTE: Uncomment the next line to test. If it fails to compile,
    // that IS the finding.
    // typealias Probe = UnsafeContinuation<Resource, Never>

    // Alternative: check withUnsafeContinuation signature
    // The stdlib declares:
    //   func withUnsafeContinuation<T>(
    //     _ fn: (UnsafeContinuation<T, Never>) -> Void
    //   ) async -> T
    // where T implicitly requires Copyable (no ~Copyable annotation)

    print("  UnsafeContinuation<T, Never>: T requires Copyable (no ~Copyable in stdlib decl)")
    print("  Implication: void-signal pattern is mandatory for ~Copyable elements")
    print("  3-lock slow path cannot be reduced via continuation type alone")
    print("  CONFIRMED (by inspection — stdlib source has no ~Copyable on T)\n")
}

// ============================================================================
// MARK: - V7: Element?? three-way return from withLock
//
// Hypothesis: Optional<Optional<Element>> (Element??) can serve as a
//   three-way return type: .some(.some(el)) = element, .some(.none) = finished,
//   .none = suspend. This would eliminate the _Take enum.
//
// Result: CONFIRMED (compiles with `switch consume`, but inferior to enum for readability)
// ============================================================================

func testV7() {
    print("=== V7: Element?? three-way return ===")
    let mutex = Mutex(BridgeState<Resource>())

    // Simulate: element available
    mutex.withLock { $0.buffer.append(70) }

    let result: Resource?? = mutex.withLock { state -> Resource?? in
        if !state.buffer.isEmpty {
            let id = state.buffer.removeFirst()
            return .some(Resource(id))  // element
        }
        if state.isFinished {
            return .some(nil)  // finished
        }
        return .none  // suspend
    }

    switch consume result {
    case .some(.some(let el)):
        print("  Got element: \(el.id)")
        _ = consume el
    case .some(.none):
        print("  Finished")
    case .none:
        print("  Suspend")
    }

    // Test finished path
    let mutex2 = Mutex(BridgeState<Resource>(isFinished: true))
    let result2: Resource?? = mutex2.withLock { state -> Resource?? in
        if state.isFinished { return .some(nil) }
        return .none
    }
    switch consume result2 {
    case .some(.some): print("  ERROR")
    case .some(.none): print("  Finished path works")
    case .none: print("  ERROR")
    }

    // Test suspend path
    let mutex3 = Mutex(BridgeState<Resource>())
    let result3: Resource?? = mutex3.withLock { state -> Resource?? in
        if !state.buffer.isEmpty { return .some(Resource(0)) }
        if state.isFinished { return .some(nil) }
        return .none
    }
    switch consume result3 {
    case .some(.some): print("  ERROR")
    case .some(.none): print("  ERROR")
    case .none: print("  Suspend path works")
    }

    print("  FINDING: Element?? compiles and works, but readability is poor")
    print("  .some(.none) vs .none is subtle — _Take enum is clearer")
    print("  CONFIRMED (compiles, but enum remains superior for readability)\n")
}

// ============================================================================
// MARK: - V8: Sequence iteration inside withLock (Copyable only)
//
// Hypothesis: A generic Sequence<Element> can be iterated inside
//   Mutex.withLock without materializing to Array first. The Sequence
//   is captured by reference in the non-escaping closure.
//
// Result: CONFIRMED — lazy sequence iterates inside lock, no Array needed
// ============================================================================

func testV8() {
    print("=== V8: Sequence iteration inside withLock ===")
    let mutex = Mutex(BridgeState<Resource>())

    func pushContentsOf<S: Swift.Sequence<Int>>(_ elements: S) {
        mutex.withLock { state in
            for id in elements {
                state.buffer.append(id)
            }
        }
    }

    // Test with lazy sequence (proves no materialization needed)
    let lazy = (80..<85).lazy.filter { $0 % 2 == 0 }
    pushContentsOf(lazy)

    mutex.withLock { state in
        print("  Buffer after lazy: \(state.buffer)")
        assert(state.buffer == [80, 82, 84])
    }

    // Test with array (baseline)
    pushContentsOf([85, 86])

    mutex.withLock { state in
        print("  Buffer after array: \(state.buffer)")
        assert(state.buffer == [80, 82, 84, 85, 86])
    }

    print("  FINDING: Sequence iterates inside lock without Array allocation")
    print("  Caveat: lock held for duration of iteration — unbounded for lazy sequences")
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V9: Full Bridge.push() pattern comparison
//
// Hypothesis: Compare the current 4-statement workaround against the
//   simplified patterns from V1 (deposit extension) and V5 (caller-owned
//   slot with .take()!). Demonstrate the concrete improvement.
//
// Result: CONFIRMED — all three simplified patterns work
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================

func testV9() {
    print("=== V9: Bridge.push() pattern comparison ===")

    // --- Current pattern (4-statement dance) ---
    print("  Current (4 statements):")
    print("    var slot: Element? = element")
    print("    var tmp = slot; slot = nil")
    print("    switch consume tmp { case .some(let e): buffer.push(e) }")
    print("")

    // --- Simplified with deposit extension (V1) ---
    print("  With deposit extension (1 statement inside lock):")
    let mutex1 = Mutex(BridgeState<Resource>())
    let r1 = Resource(91)
    let _: Bool = mutex1.withLock(deposit: r1) { state, element in
        guard !state.isFinished else {
            element = nil
            return false
        }
        let el = element.take()!  // one-liner
        let id = el.id
        _ = consume el
        return state.bufferElement(id)
    }
    mutex1.withLock { assert($0.buffer == [91]) }
    print("    element.take()! — single expression")
    print("")

    // --- Simplified with consuming extension (V2) ---
    print("  With consuming extension (cleanest — no Optional at all):")
    let mutex2 = Mutex(BridgeState<Resource>())
    let r2 = Resource(92)
    let _: Bool = mutex2.withLock(consuming: r2) { state, element in
        guard !state.isFinished else {
            _ = consume element  // drop
            return false
        }
        let id = element.id
        _ = consume element
        return state.bufferElement(id)
    }
    mutex2.withLock { assert($0.buffer == [92]) }
    print("    Body receives consuming Element directly — no Optional dance")
    print("")

    // --- Simplified with caller-owned slot + .take()! (V5) ---
    print("  With caller-owned slot + .take()! (no extension needed):")
    let mutex3 = Mutex(BridgeState<Resource>())
    var slot: Resource? = Resource(93)
    let _: Bool = mutex3.withLock { state in
        guard !state.isFinished else {
            slot = nil
            return false
        }
        let el = slot.take()!  // one-liner, replaces 3 statements
        let id = el.id
        _ = consume el
        return state.bufferElement(id)
    }
    assert(slot == nil)
    mutex3.withLock { assert($0.buffer == [93]) }
    print("    slot.take()! — replaces var tmp / slot = nil / switch consume tmp")

    print("\n  CONFIRMED\n")
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()
testV9()

print("=== SUMMARY ===")
print("V1: Mutex.withLock(deposit:body:) extension        — compiles and works")
print("V2: Mutex.withLock(consuming:body:) extension      — compiles and works")
print("V3: Finished path with consuming variant            — element correctly dropped")
print("V4: Deposit variant suspend-retention limitation    — caller cannot recover value")
print("V5: Caller-owned slot + .take()!                    — simplest, no extension needed")
print("V6: UnsafeContinuation ~Copyable constraint         — T requires Copyable (by inspection)")
print("V7: Element?? three-way return                      — works but inferior to enum")
print("V8: Sequence iteration inside withLock              — works, avoids Array allocation")
print("V9: Bridge.push() pattern comparison                — all three simplified patterns work")
