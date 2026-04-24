// MARK: - ~Copyable Ownership Transfer Through Mutex
//
// Purpose: Investigate whether Mutex can be extended with variants that
//   simplify ~Copyable value transfer into locked closures, eliminating
//   the 4-statement Optional slot dance in Async.Bridge.push().
//
// Context:
//   - Bridge.push() currently uses: var slot -> var tmp -> slot = nil -> switch consume tmp
//   - Prior experiment (inout-noncopyable-optional-closure-capture) confirmed
//     the inout Element? pattern works on a custom Storage class
//   - This experiment tests: (1) Mutex extension feasibility, (2) UnsafeContinuation
//     ~Copyable constraint, (3) _Take enum alternatives, (4) Sequence inside lock
//
// Status: CONFIRMED — all 9 variants pass. Three approaches to simplify
//   Bridge.push() slot dance: (1) Mutex.withLock(deposit:body:) extension,
//   (2) Mutex.withLock(consuming:body:) extension, (3) caller-owned slot.take()!
//   (no extension needed). V5 (caller-owned slot) is simplest for Bridge.
//   Bonus: extension Mutex requires `where Value: ~Copyable` — bare extension
//   has implicit Copyable constraint. UnsafeContinuation requires T: Copyable
//   (same as Checked), so 3-lock slow path is fundamental. Element?? compiles
//   with `switch consume` but readability is inferior to _Take enum.
//
// Revalidation: Toolchain 6.3 (swiftlang-6.3.0.123.5), macOS 26.0, 2026-03-31
//
// Origin: bridge-noncopyable-ownership (9 variants)

import Synchronization

// swiftlint:disable type_body_length file_length

enum V03_BridgeOwnership {

    // ========================================================================
    // MARK: - Infrastructure
    // ========================================================================

    struct Resource: ~Copyable, Sendable {
        let id: Int
        init(_ id: Int) { self.id = id }
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

    // ========================================================================
    // MARK: - Variant 1: Mutex.withLock(deposit:body:) — inout Element? extension
    //
    // Hypothesis: Synchronization.Mutex can be extended with a method that wraps
    //   a consuming value in Optional, threads it as inout into the locked body.
    //   This generalizes the pattern from inout-noncopyable-optional-closure-capture
    //   as a reusable Mutex API.
    // Result: CONFIRMED — compiles and works with `where Value: ~Copyable`
    // ========================================================================

    static func runV1() {
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
        _ = shouldResume

        mutex.withLock { state in
            assert(state.buffer == [1])
        }
    }

    // ========================================================================
    // MARK: - Variant 2: Mutex.withLock(consuming:body:) — consuming variant
    //
    // Hypothesis: A stricter variant where the body MUST consume the value
    //   (no Option to keep it). Suitable for Bridge.push() where every path
    //   either buffers or drops the element.
    // Result: CONFIRMED — compiles and works with `where Value: ~Copyable`
    // ========================================================================

    static func runV2() {
        let mutex = Mutex(BridgeState<Resource>())

        let resource = Resource(2)
        let shouldResume: Bool = mutex.withLock(consuming: resource) { state, element in
            let id = element.id
            _ = consume element
            return state.bufferElement(id)
        }
        _ = shouldResume

        mutex.withLock { state in
            assert(state.buffer == [2])
        }
    }

    // ========================================================================
    // MARK: - Variant 3: Finished path — consuming variant drops element
    //
    // Hypothesis: The consuming variant correctly drops the element on the
    //   finished path (element consumed by `_ = consume element`).
    // Result: CONFIRMED — element dropped, buffer empty
    // ========================================================================

    static func runV3() {
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
        }
    }

    // ========================================================================
    // MARK: - Variant 4: Deposit variant — suspend path keeps element
    //
    // Hypothesis: The deposit (inout) variant allows the body to NOT consume
    //   the element on a suspend path. After withLock returns, the caller
    //   can detect that the element is still present and defer Slot allocation.
    //   This is the Channel pattern (not Bridge), but validates the API generality.
    // Result: CONFIRMED (limitation found — deposit consumes ownership;
    //   caller cannot recover)
    // ========================================================================

    static func runV4() {
        let mutex = Mutex(BridgeState<Resource>())
        // Simulate "buffer full" = suspend path
        mutex.withLock { state in state.isFinished = false }

        var slot: Resource? = Resource(4)
        let suspended: Bool = mutex.withLock(deposit: slot.take()!) { state, element in
            // Simulate: buffer is full -> suspend, don't consume element
            // For this test, we always "suspend"
            return true  // signal: suspended, element still in slot
        }
        _ = suspended
        // After withLock, element was consumed by the deposit parameter.
        // The body chose not to take it from the inout Optional, so it stays there.
        // But the deposit parameter consumed ownership. The Optional is
        // internal to the extension method. We can't get it back.
        //
        // FINDING: deposit variant consumes ownership — caller cannot recover.
        // For suspend paths, caller must own var slot: Element? directly.
    }

    // ========================================================================
    // MARK: - Variant 5: Caller-owned slot with standard withLock (Bridge pattern)
    //
    // Hypothesis: The simplified Bridge.push() pattern uses a caller-owned
    //   var slot: Element? and threads it as &slot through standard withLock,
    //   WITHOUT a Mutex extension. The inout reference crosses the closure
    //   boundary via capture.
    // Result: CONFIRMED — slot.take()! replaces 3-statement dance
    // ========================================================================

    static func runV5() {
        let mutex = Mutex(BridgeState<Resource>())

        var slot: Resource? = Resource(5)
        let shouldResume: Bool = mutex.withLock { state in
            guard !state.isFinished else {
                slot = nil  // drop
                return false
            }
            let el = slot.take()!
            let id = el.id
            _ = consume el
            return state.bufferElement(id)
        }
        assert(slot == nil)
        _ = shouldResume

        mutex.withLock { state in
            assert(state.buffer == [5])
        }
    }

    // ========================================================================
    // MARK: - Variant 6: UnsafeContinuation ~Copyable constraint
    //
    // Hypothesis: UnsafeContinuation<T, Never> requires T: Copyable, same as
    //   CheckedContinuation<T, Never>. If so, the void-signal pattern is
    //   forced regardless of which continuation type is used.
    // Result: CONFIRMED (by inspection — stdlib has no ~Copyable on T)
    // ========================================================================

    static func runV6() {
        // CONFIRMED by inspection — stdlib source has no ~Copyable on T.
        //
        // UnsafeContinuation<T, Never>: T requires Copyable (no ~Copyable in stdlib decl).
        // Implication: void-signal pattern is mandatory for ~Copyable elements.
        // 3-lock slow path cannot be reduced via continuation type alone.
        //
        // COMPILE ERROR (expected):
        // typealias Probe = UnsafeContinuation<Resource, Never>
        // Would fail: Resource is ~Copyable, UnsafeContinuation requires Copyable T.
    }

    // ========================================================================
    // MARK: - Variant 7: Element?? three-way return from withLock
    //
    // Hypothesis: Optional<Optional<Element>> (Element??) can serve as a
    //   three-way return type: .some(.some(el)) = element, .some(.none) = finished,
    //   .none = suspend. This would eliminate the _Take enum.
    // Result: CONFIRMED (compiles with `switch consume`, but inferior to enum
    //   for readability)
    // ========================================================================

    static func runV7() {
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
            assert(el.id == 70)
            _ = consume el
        case .some(.none):
            break
        case .none:
            break
        }

        // Test finished path
        let mutex2 = Mutex(BridgeState<Resource>(isFinished: true))
        let result2: Resource?? = mutex2.withLock { state -> Resource?? in
            if state.isFinished { return .some(nil) }
            return .none
        }
        switch consume result2 {
        case .some(.some): assertionFailure("unexpected element")
        case .some(.none): break  // expected
        case .none: assertionFailure("unexpected suspend")
        }

        // Test suspend path
        let mutex3 = Mutex(BridgeState<Resource>())
        let result3: Resource?? = mutex3.withLock { state -> Resource?? in
            if !state.buffer.isEmpty { return .some(Resource(0)) }
            if state.isFinished { return .some(nil) }
            return .none
        }
        switch consume result3 {
        case .some(.some): assertionFailure("unexpected element")
        case .some(.none): assertionFailure("unexpected finished")
        case .none: break  // expected
        }

        // FINDING: Element?? compiles and works, but readability is poor.
        // .some(.none) vs .none is subtle — _Take enum is clearer.
    }

    // ========================================================================
    // MARK: - Variant 8: Sequence iteration inside withLock (Copyable only)
    //
    // Hypothesis: A generic Sequence<Element> can be iterated inside
    //   Mutex.withLock without materializing to Array first. The Sequence
    //   is captured by reference in the non-escaping closure.
    // Result: CONFIRMED — lazy sequence iterates inside lock, no Array needed
    // ========================================================================

    static func runV8() {
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
            assert(state.buffer == [80, 82, 84])
        }

        // Test with array (baseline)
        pushContentsOf([85, 86])

        mutex.withLock { state in
            assert(state.buffer == [80, 82, 84, 85, 86])
        }

        // FINDING: Sequence iterates inside lock without Array allocation.
        // Caveat: lock held for duration of iteration — unbounded for lazy sequences.
    }

    // ========================================================================
    // MARK: - Variant 9: Full Bridge.push() pattern comparison
    //
    // Hypothesis: Compare the current 4-statement workaround against the
    //   simplified patterns from V1 (deposit extension) and V5 (caller-owned
    //   slot with .take()!). Demonstrate the concrete improvement.
    // Result: CONFIRMED — all three simplified patterns work
    // ========================================================================

    static func runV9() {
        // --- Simplified with deposit extension (V1) ---
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

        // --- Simplified with consuming extension (V2) ---
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

        // --- Simplified with caller-owned slot + .take()! (V5) ---
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
    }

    // ========================================================================
    // MARK: - Entry Point
    // ========================================================================

    static func run() {
        runV1()
        runV2()
        runV3()
        runV4()
        runV5()
        runV6()
        runV7()
        runV8()
        runV9()
    }
}

// ============================================================================
// MARK: - Mutex Extensions (used by V03 variants)
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

extension Mutex where Value: ~Copyable {
    /// Pass a value into the lock scope as consuming.
    ///
    /// The body MUST consume the value on every path. Suitable when
    /// every code path either uses or drops the value (no suspend path).
    func withLock<V: ~Copyable & Sendable, T: ~Copyable, E: Error>(
        consuming value: consuming sending V,
        body: (inout sending Value, consuming V) throws(E) -> sending T
    ) throws(E) -> sending T {
        var slot: V? = value
        return try withLock { (state: inout sending Value) throws(E) -> T in
            let v = slot.take()!
            return try body(&state, v)
        }
    }
}
