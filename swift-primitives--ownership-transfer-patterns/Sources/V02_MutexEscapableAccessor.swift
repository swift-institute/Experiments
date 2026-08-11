// MARK: - ~Escapable Mutex Accessor: Can We Eliminate withLock Closures?
//
// Purpose: Test whether a Mutex can expose a ~Escapable locked view via
//   _read/_modify coroutines, replacing the closure-based withLock pattern
//   with direct property access. This is the natural evolution from:
//     withUnsafeBufferPointer { } -> Span (~Escapable)
//     withLock { state in ... }   -> mutex.locked.field (this experiment)
//
// Status: CONFIRMED (V1-V3, V5) / REFUTED (V4). The ~Escapable accessor
//   pattern works: direct property access, consuming in/out, zero closures,
//   zero Optional wrappers, zero .take()!. But Synchronization.Mutex cannot
//   support it — yield cannot appear inside a closure, and handle._lock()
//   is internal. A coroutine-capable Mutex implementation is required.
//
// Revalidation: Toolchain 6.3 (swiftlang-6.3.0.123.5), macOS 26.0, 2026-03-31
//
// Origin: mutex-escapable-accessor (5 variants)

import Synchronization

// swiftlint:disable type_body_length

enum V02_MutexEscapableAccessor {

    // ========================================================================
    // MARK: - Infrastructure
    // ========================================================================

    struct Resource: ~Copyable, Sendable {
        var id: Int
        init(_ id: Int) { self.id = id }
    }

    struct State: ~Copyable {
        var count: Int = 0
        var resource: Resource? = nil
    }

    /// A locked view of a value. ~Escapable ensures it cannot outlive the
    /// coroutine scope that yields it. ~Copyable prevents aliasing.
    struct Locked<Value: ~Copyable>: ~Copyable, ~Escapable {
        let pointer: UnsafeMutablePointer<Value>

        @_lifetime(borrow pointer)
        init(_ pointer: UnsafeMutablePointer<Value>) {
            self.pointer = pointer
        }

        var value: Value {
            _read { yield unsafe pointer.pointee }
            _modify { yield &pointer.pointee }
        }
    }

    /// Toy mutex — no real locking, just tests the accessor pattern.
    /// Uses heap-allocated pointer storage for stable address across coroutine suspension.
    final class ToyMutex<Value: ~Copyable & Sendable>: @unchecked Sendable {
        private let _pointer: UnsafeMutablePointer<Value>

        init(_ value: consuming sending Value) {
            _pointer = .allocate(capacity: 1)
            unsafe _pointer.initialize(to: value)
        }

        deinit {
            unsafe _pointer.deinitialize(count: 1)
            _pointer.deallocate()
        }

        var locked: Locked<Value> {
            _read {
                yield unsafe Locked<Value>(_pointer)
            }
            _modify {
                var view = unsafe Locked<Value>(_pointer)
                yield &view
            }
        }
    }

    // ========================================================================
    // MARK: - Variant 1: Basic ~Escapable locked view
    //
    // Hypothesis: Read/write Copyable fields through the locked accessor.
    // Result: CONFIRMED
    // ========================================================================

    static func runV1() {
        let mutex = ToyMutex(State())

        mutex.locked.value.count = 42
        let c = mutex.locked.value.count
        assert(c == 42)
    }

    // ========================================================================
    // MARK: - Variant 2: Consume INTO locked state
    //
    // Hypothesis: Move a ~Copyable value into locked state via _modify accessor.
    // Result: CONFIRMED
    // ========================================================================

    static func runV2() {
        let mutex = ToyMutex(State())

        let r = Resource(2)
        mutex.locked.value.resource = consume r

        let id = mutex.locked.value.resource?.id
        assert(id == 2)
    }

    // ========================================================================
    // MARK: - Variant 3: Consume OUT of locked state
    //
    // Hypothesis: Move a ~Copyable value out of locked state via .take().
    // Result: CONFIRMED
    // ========================================================================

    static func runV3() {
        let mutex = ToyMutex(State())
        mutex.locked.value.resource = Resource(3)

        var r = mutex.locked.value.resource.take()
        assert(r != nil)
        assert(r!.id == 3)
        assert(mutex.locked.value.resource == nil)
        r = nil
        _ = consume r
    }

    // ========================================================================
    // MARK: - Variant 4: Synchronization.Mutex — yield cannot compose with withLock
    //
    // Hypothesis: REFUTED before compilation. `yield` is a coroutine keyword
    //   that can only appear in _read/_modify accessor bodies. It CANNOT appear
    //   inside a closure — even a non-escaping closure like withLock's body.
    //
    //   This means Synchronization.Mutex CANNOT be wrapped with a coroutine
    //   accessor from outside. It would need native _read/_modify support
    //   (exposing raw lock/unlock or implementing the coroutine internally).
    //
    //   Synchronization.Mutex.withLock implementation (from stdlib source):
    //     handle._lock()
    //     defer { handle._unlock() }
    //     return try unsafe body(&value._address.pointee)
    //
    //   handle._lock() and handle._unlock() are internal to Synchronization.
    //   We cannot access them from an extension.
    //
    // Result: REFUTED (by construction — yield is not valid inside closures)
    // ========================================================================

    static func runV4() {
        // REFUTED — yield cannot appear inside a closure.
        // Synchronization.Mutex would need native _read/_modify support
        // or exposed lock()/unlock() methods to build coroutine accessors.
        //
        // No executable code — this variant is documentation of a confirmed
        // language limitation.
    }

    // ========================================================================
    // MARK: - Variant 5: Consuming parameter through locked accessor
    //
    // Hypothesis: The end-state for Bridge.push() — move a consuming parameter
    //   directly into locked state without any closure or Optional wrapper.
    // Result: CONFIRMED
    // ========================================================================

    static func runV5() {
        let mutex = ToyMutex(State())

        func push(_ element: consuming sending Resource) {
            mutex.locked.value.resource = consume element
        }

        push(Resource(5))
        let id = mutex.locked.value.resource?.id
        assert(id == 5)
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
    }
}
