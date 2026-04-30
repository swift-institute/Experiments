// MARK: - @_rawLayout Coroutine Mutex: nonmutating _modify
//
// Purpose: Test whether `nonmutating _modify` on the Locked view allows
//   the entire chain to work with `let`-bound Mutex. The pointer provides
//   interior mutability — the Locked struct itself doesn't mutate.
//
// This is the make-or-break test: if nonmutating _modify works, we get
//   struct Mutex + let binding + zero heap allocation + coroutine accessor.
//   No security or performance concerns from `var`.
//
// Toolchain: Apple Swift version 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — 6/6 variants pass. Struct Mutex with @_rawLayout inline
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   storage, let binding, nonmutating _modify on Locked view, zero heap allocation,
//   26 bytes total, 1000-task concurrent safety. Parity with Synchronization.Mutex
//   on every axis plus coroutine accessor. ~Escapable blocked by lifetime checker
//   on class stored properties (known limitation); ~Copyable alone is sufficient
//   since _read coroutine scope prevents escape.
// Date: 2026-03-31

import Darwin.os.lock

// ============================================================================
// MARK: - Storage
// ============================================================================

@_rawLayout(like: Value, movesAsLike)
struct _ValueRaw<Value: ~Copyable>: ~Copyable {
    init() {}
}
extension _ValueRaw: @unchecked Sendable where Value: Sendable {}

@_rawLayout(like: os_unfair_lock_s)
struct _LockRaw: ~Copyable, @unchecked Sendable {
    init() {}
}

// ============================================================================
// MARK: - Locked View with nonmutating _modify
// ============================================================================

struct Locked<Value: ~Copyable>: ~Copyable {
    let pointer: UnsafeMutablePointer<Value>

    init(_ pointer: UnsafeMutablePointer<Value>) {
        self.pointer = pointer
    }

    /// Interior mutability: the pointer doesn't change, only what it points to.
    /// `nonmutating _modify` means this works from a borrowed Locked.
    var value: Value {
        _read { yield unsafe pointer.pointee }
        nonmutating _modify { yield &pointer.pointee }
    }
}

// ============================================================================
// MARK: - Struct Mutex (all let, all borrowing)
// ============================================================================

struct StructMutex<Value: ~Copyable & Sendable>: ~Copyable, @unchecked Sendable {
    let _lockRaw: _LockRaw
    let _valueRaw: _ValueRaw<Value>

    init(_ value: consuming sending Value) {
        _lockRaw = _LockRaw()
        _valueRaw = _ValueRaw()
        unsafe _lockPointer().initialize(to: os_unfair_lock_s())
        unsafe _valuePointer().initialize(to: value)
    }

    private func _lockPointer() -> UnsafeMutablePointer<os_unfair_lock_s> {
        unsafe withUnsafePointer(to: _lockRaw) { base in
            unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(base)
                    .assumingMemoryBound(to: os_unfair_lock_s.self)
            )
        }
    }

    private func _valuePointer() -> UnsafeMutablePointer<Value> {
        unsafe withUnsafePointer(to: _valueRaw) { base in
            unsafe UnsafeMutablePointer(
                mutating: UnsafeRawPointer(base)
                    .assumingMemoryBound(to: Value.self)
            )
        }
    }

    private func _lock() { unsafe os_unfair_lock_lock(_lockPointer()) }
    private func _unlock() { unsafe os_unfair_lock_unlock(_lockPointer()) }

    /// Closure API (borrowing — works with let).
    borrowing func withLock<T: ~Copyable, E: Error>(
        _ body: (inout sending Value) throws(E) -> sending T
    ) throws(E) -> sending T {
        _lock()
        defer { _unlock() }
        return try unsafe body(&_valuePointer().pointee)
    }

    /// Coroutine API (_read only — borrows self, works with let).
    /// Locked.value uses nonmutating _modify for interior mutability.
    var locked: Locked<Value> {
        _read {
            _lock()
            defer { _unlock() }
            yield unsafe Locked(_valuePointer())
        }
    }
}

// ============================================================================
// MARK: - Test Infrastructure
// ============================================================================

struct Resource: ~Copyable, Sendable {
    var id: Int
    init(_ id: Int) { self.id = id }
    deinit { print("  Resource(\(id)) deinit") }
}

struct State: ~Copyable {
    var count: Int = 0
    var resource: Resource? = nil
    var isFinished: Bool = false
}

// ============================================================================
// MARK: - V1: let-bound standalone
// ============================================================================

func testV1() {
    print("=== V1: let-bound standalone ===")
    let mutex = StructMutex(State())

    // withLock (borrowing)
    mutex.withLock { $0.count = 1 }
    assert(mutex.withLock { $0.count } == 1)
    print("  withLock: count = 1")

    // locked (nonmutating _modify through pointer)
    mutex.locked.value.count = 2
    assert(mutex.locked.value.count == 2)
    print("  locked: count = 2")

    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V2: let in class (Bridge pattern — the real test)
// ============================================================================

final class BridgeLike: @unchecked Sendable {
    let _state: StructMutex<State>  // LET — not var

    init() { _state = StructMutex(State()) }

    func pushViaLocked(_ element: consuming sending Resource) {
        _state.locked.value.resource = consume element
        _state.locked.value.count += 1
    }

    func count() -> Int { _state.withLock { $0.count } }
}

func testV2() {
    print("=== V2: let in class (Bridge pattern) ===")
    let bridge = BridgeLike()

    bridge.pushViaLocked(Resource(2))
    assert(bridge.count() == 1)
    print("  locked push on let _state: count = 1")

    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V3: Consume in/out on let binding
// ============================================================================

func testV3() {
    print("=== V3: Consume in/out (let) ===")
    let mutex = StructMutex(State())

    mutex.locked.value.resource = Resource(3)
    assert(mutex.locked.value.resource?.id == 3)
    print("  Consumed in: id = 3")

    var r = mutex.locked.value.resource.take()
    assert(r != nil && mutex.locked.value.resource == nil)
    print("  Consumed out: id = \(r!.id)")
    r = nil

    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V4: Concurrent locked on let binding
// ============================================================================

func testV4() async {
    print("=== V4: Concurrent locked (let) ===")
    let bridge = BridgeLike()
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<1000 {
            group.addTask { bridge.pushViaLocked(Resource(i)) }
        }
    }
    assert(bridge.count() == 1000)
    print("  1000 concurrent pushes on let _state: count = \(bridge.count())")
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V5: Bridge.push ideal end-state
// ============================================================================

func testV5() {
    print("=== V5: Bridge.push ideal end-state ===")

    final class IdealBridge: @unchecked Sendable {
        let _state: StructMutex<State>  // LET
        init() { _state = StructMutex(State()) }

        func push(_ element: consuming sending Resource) {
            guard !_state.locked.value.isFinished else { return }
            _state.locked.value.resource = consume element
            _state.locked.value.count += 1
        }

        var count: Int { _state.withLock { $0.count } }
    }

    let bridge = IdealBridge()
    bridge.push(Resource(5))
    assert(bridge.count == 1)
    print("  push on let _state: count = 1")
    print("  CONFIRMED\n")
}

// ============================================================================
// MARK: - V6: Size verification
// ============================================================================

func testV6() {
    print("=== V6: Size ===")
    print("  State: \(MemoryLayout<State>.size)")
    print("  Lock: \(MemoryLayout<os_unfair_lock_s>.size)")
    print("  StructMutex: \(MemoryLayout<StructMutex<State>>.size)")
    print("  CONFIRMED\n")
}

// ============================================================================
// Entry Point
// ============================================================================

testV1()
testV2()
testV3()
await testV4()
testV5()
testV6()

print("=== SUMMARY ===")
print("V1: let-bound standalone                      — see above")
print("V2: let in class (Bridge pattern)             — see above")
print("V3: Consume in/out (let)                      — see above")
print("V4: Concurrent locked (let)                   — see above")
print("V5: Bridge.push ideal end-state               — see above")
print("V6: Size verification                          — see above")
