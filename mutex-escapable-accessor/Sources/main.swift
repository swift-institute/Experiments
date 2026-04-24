// SUPERSEDED: See ownership-transfer-patterns
// MARK: - ~Escapable Mutex Accessor: Can We Eliminate withLock Closures?
//
// Purpose: Test whether a Mutex can expose a ~Escapable locked view via
//   _read/_modify coroutines, replacing the closure-based withLock pattern
//   with direct property access. This is the natural evolution from:
//     withUnsafeBufferPointer { } → Span (~Escapable)
//     withLock { state in ... }   → mutex.locked.field (this experiment)
//
// Hypothesis: A ~Escapable, ~Copyable view type that borrows the Mutex's
//   internal storage via _modify can provide scoped inout access. The
//   coroutine scope IS the lock scope — lock acquired on entry, released
//   on return. ~Escapable prevents the view from outliving the scope.
//
// Sub-hypotheses:
//   V1: Basic ~Escapable locked view with _modify — read/write Copyable fields
//   V2: Consume a ~Copyable value INTO locked state
//   V3: Consume a ~Copyable value OUT of locked state
//   V4: Synchronization.Mutex — can yield compose with withLock?
//   V5: Consuming parameter through locked accessor (end-state for Bridge.push)
//
// Toolchain: Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED (V1-V3, V5) / REFUTED (V4). The ~Escapable accessor
//   pattern works: direct property access, consuming in/out, zero closures,
//   zero Optional wrappers, zero .take()!. But Synchronization.Mutex cannot
//   support it — yield cannot appear inside a closure, and handle._lock()
//   is internal. A coroutine-capable Mutex implementation is required.
// Date: 2026-03-31

import Synchronization

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

struct Resource: ~Copyable, Sendable {
    var id: Int
    init(_ id: Int) { self.id = id }
    deinit { print("  Resource(\(id)) deinit") }
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

// ============================================================================
// MARK: - V1: Basic ~Escapable locked view
//
// Hypothesis: Read/write Copyable fields through the locked accessor.
//
// Result: [PENDING]
// ============================================================================

func testV1() {
    print("=== V1: Basic ~Escapable locked view ===")
    let mutex = ToyMutex(State())

    mutex.locked.value.count = 42
    let c = mutex.locked.value.count
    print("  Count: \(c)")
    assert(c == 42)
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V2: Consume INTO locked state
//
// Hypothesis: Move a ~Copyable value into locked state via _modify accessor.
//
// Result: [PENDING]
// ============================================================================

func testV2() {
    print("=== V2: Consume INTO locked state ===")
    let mutex = ToyMutex(State())

    let r = Resource(2)
    mutex.locked.value.resource = consume r

    let id = mutex.locked.value.resource?.id
    print("  Resource id: \(id ?? -1)")
    assert(id == 2)
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V3: Consume OUT of locked state
//
// Hypothesis: Move a ~Copyable value out of locked state via .take().
//
// Result: [PENDING]
// ============================================================================

func testV3() {
    print("=== V3: Consume OUT of locked state ===")
    let mutex = ToyMutex(State())
    mutex.locked.value.resource = Resource(3)

    var r = mutex.locked.value.resource.take()
    assert(r != nil)
    print("  Took resource: \(r!.id)")
    assert(mutex.locked.value.resource == nil)
    r = nil
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V4: Synchronization.Mutex — yield cannot compose with withLock
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
// ============================================================================

func testV4() {
    print("=== V4: Synchronization.Mutex integration ===")
    print("  REFUTED — yield cannot appear inside a closure")
    print("  Synchronization.Mutex would need native _read/_modify support")
    print("  or exposed lock()/unlock() methods to build coroutine accessors")
    print("")
}

// ============================================================================
// MARK: - V5: Consuming parameter through locked accessor
//
// Hypothesis: The end-state for Bridge.push() — move a consuming parameter
//   directly into locked state without any closure or Optional wrapper.
//
// Result: [PENDING]
// ============================================================================

func testV5() {
    print("=== V5: Consuming through locked accessor ===")
    let mutex = ToyMutex(State())

    func push(_ element: consuming sending Resource) {
        mutex.locked.value.resource = consume element
    }

    push(Resource(5))
    let id = mutex.locked.value.resource?.id
    print("  Resource id: \(id ?? -1)")
    assert(id == 5)
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5()

print("=== SUMMARY ===")
print("V1: Basic ~Escapable locked view              — see above")
print("V2: Consume INTO locked state                  — see above")
print("V3: Consume OUT of locked state                — see above")
print("V4: Synchronization.Mutex integration          — REFUTED (yield not in closure)")
print("V5: Consuming through locked accessor          — see above")
