// MARK: - noncopyable-peek-escapable
//
// Purpose: Determine if ~Escapable types can enable non-closure peek
//          for ~Copyable deque elements via property-based API.
// Hypothesis: Non-optional ~Escapable return works (proven by Property.View,
//             Span, mutex-escapable-accessor). Optional<~Escapable> is blocked
//             by nil-construction lifetime requirements.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — All 7 variants pass in debug and release.
//         Optional<~Escapable> works for computed properties/functions/coroutines.
//         The key insight: the blocker is ~Copyable + Optional (consumption),
//         NOT ~Escapable + Optional (lifetime). A Copyable ~Escapable wrapper
//         like Borrowed<T> CAN be wrapped in Optional.
// Date: 2026-03-31
//
// Variants:
//   V1: Borrowed<T: ~Copyable> type definition — CONFIRMED (Build Succeeded)
//   V2: Non-optional _read yield of Borrowed from ~Copyable container — CONFIRMED (Output: 42)
//   V3: Function returning Optional<Span<Int>> — CONFIRMED (.some and nil paths)
//   V4: Property returning Optional<Span<Int>> — CONFIRMED (.some and nil paths)
//   V5: _read yielding Optional<Borrowed<T>> — CONFIRMED (.some and nil paths)
//   V6: Two-step guard + non-optional accessor — CONFIRMED (Output: 99)
//   V7: Closure-based peek (status quo control) — CONFIRMED (Output: 77)
//
// Results Summary:
//   V1: CONFIRMED — Borrowed<T: ~Copyable>: ~Escapable compiles
//   V2: CONFIRMED — _read yields Borrowed, caller chains .pointee.value
//   V3: CONFIRMED — Optional<Span<Int>> from function with nil return
//   V4: CONFIRMED — Optional<Span<Int>> from borrowing get property with nil return
//   V5: CONFIRMED — _read yields Optional<Borrowed<Resource>> including nil path
//   V6: CONFIRMED — Two-step isEmpty + non-optional _read works
//   V7: CONFIRMED — Closure-based peek works (status quo)

// ============================================================================
// Shared Types
// ============================================================================

struct Resource: ~Copyable {
    var value: Int
    init(_ value: Int) { self.value = value }
}

// ============================================================================
// MARK: - V1: Borrowed<T: ~Copyable> Wrapper Type
// Hypothesis: A Copyable ~Escapable wrapper holding UnsafePointer<T> compiles.
//             Per [IMPL-065], this is a "pointer-based view into a container."
// Result: CONFIRMED
// ============================================================================

struct Borrowed<T: ~Copyable>: ~Escapable {
    let _pointer: UnsafePointer<T>

    @_lifetime(borrow pointer)
    init(_ pointer: UnsafePointer<T>) {
        unsafe _pointer = pointer
    }

    var pointee: T {
        _read {
            yield unsafe _pointer.pointee
        }
    }
}

// ============================================================================
// MARK: - V2: Non-optional _read yield of Borrowed from ~Copyable container
// Hypothesis: _read can yield Borrowed<Resource> from a ~Copyable container.
//             The lifetime chain: _read borrows self -> accesses _storage ->
//             creates Borrowed tied to _storage -> yields to caller.
// Result: CONFIRMED
// ============================================================================

struct V2Box: ~Copyable {
    let _storage: UnsafeMutablePointer<Resource>

    init(_ value: consuming Resource) {
        _storage = .allocate(capacity: 1)
        unsafe _storage.initialize(to: consume value)
    }

    deinit {
        unsafe _storage.deinitialize(count: 1)
        unsafe _storage.deallocate()
    }

    var front: Borrowed<Resource> {
        _read {
            yield unsafe Borrowed(UnsafePointer(_storage))
        }
    }
}

// ============================================================================
// MARK: - V3: Function returning Optional<Span<Int>>
// Hypothesis: A function with @_lifetime can return Optional<Span<Int>>,
//             including nil for the empty case.
// Key test: Does Optional<~Escapable>.none have a viable lifetime source
//           when the function has @_lifetime(borrow) annotation?
// Result: CONFIRMED
// ============================================================================

@_lifetime(borrow values)
func optionalSpan(_ values: borrowing [Int]) -> Span<Int>? {
    guard !values.isEmpty else { return nil }
    return values.span
}

// ============================================================================
// MARK: - V4: Property returning Optional<Span<Int>>
// Hypothesis: A computed property can return Optional<Span<Int>> with
//             @_lifetime(borrow self) and nil fallback.
// Key test: Same as V3 but through property accessor.
// Result: CONFIRMED
// ============================================================================

struct V4Container {
    var _values: [Int]

    var optionalSpan: Span<Int>? {
        @_lifetime(borrow self)
        borrowing get {
            guard !_values.isEmpty else { return nil }
            return _values.span
        }
    }
}

// ============================================================================
// MARK: - V5: _read yielding Optional<Borrowed<T>>
// Hypothesis: _read can yield Optional<Borrowed<Resource>> with nil fallback.
// Key test: Combines the _read coroutine with Optional<~Escapable>.
// Result: CONFIRMED
// ============================================================================

struct V5Box: ~Copyable {
    let _storage: UnsafeMutablePointer<Resource>
    var _count: Int

    init(_ value: consuming Resource) {
        _storage = .allocate(capacity: 1)
        unsafe _storage.initialize(to: consume value)
        _count = 1
    }

    deinit {
        if _count > 0 { unsafe _storage.deinitialize(count: _count) }
        unsafe _storage.deallocate()
    }

    var front: Borrowed<Resource>? {
        _read {
            guard _count > 0 else { yield nil; return }
            yield unsafe Borrowed(UnsafePointer(_storage))
        }
    }
}

// ============================================================================
// MARK: - V6: Two-step guard + non-optional accessor
// Hypothesis: Splitting isEmpty check from non-optional Borrowed accessor works.
//             Per [IMPL-040], the precondition is valid since the caller can
//             check isEmpty first.
// Result: CONFIRMED
// ============================================================================

struct V6Box: ~Copyable {
    let _storage: UnsafeMutablePointer<Resource>
    var _count: Int

    init(_ value: consuming Resource) {
        _storage = .allocate(capacity: 1)
        unsafe _storage.initialize(to: consume value)
        _count = 1
    }

    deinit {
        if _count > 0 { unsafe _storage.deinitialize(count: _count) }
        unsafe _storage.deallocate()
    }

    var isEmpty: Bool { _count == 0 }

    /// Non-optional borrowed access to the front element.
    /// Caller MUST check isEmpty first.
    var front: Borrowed<Resource> {
        _read {
            precondition(_count > 0, "front on empty container")
            yield unsafe Borrowed(UnsafePointer(_storage))
        }
    }
}

// ============================================================================
// MARK: - V7: Closure-based peek (status quo control)
// Hypothesis: The current closure pattern works for ~Copyable elements.
//             This is the production pattern from Queue.DoubleEnded.
// Result: CONFIRMED
// ============================================================================

struct V7Box: ~Copyable {
    let _storage: UnsafeMutablePointer<Resource>
    var _count: Int

    init(_ value: consuming Resource) {
        _storage = .allocate(capacity: 1)
        unsafe _storage.initialize(to: consume value)
        _count = 1
    }

    deinit {
        if _count > 0 { unsafe _storage.deinitialize(count: _count) }
        unsafe _storage.deallocate()
    }

    func peek<R: ~Copyable>(_ body: (borrowing Resource) -> R) -> R? {
        guard _count > 0 else { return nil }
        return unsafe body(_storage.pointee)
    }
}

// ============================================================================
// MARK: - Main: Run confirmed variants
// ============================================================================

// V1: Type compiled
print("V1: Borrowed<T> type definition — compiled")

// V2: Non-optional _read yield
do {
    var v2box = V2Box(Resource(42))
    let v2value = v2box.front.pointee.value
    print("V2: Non-optional _read yield — \(v2value == 42 ? "CONFIRMED" : "FAILED"): \(v2value)")
}

// V6: Two-step guard + non-optional
do {
    var v6box = V6Box(Resource(99))
    if !v6box.isEmpty {
        let v6value = v6box.front.pointee.value
        print("V6: Two-step guard + non-optional — \(v6value == 99 ? "CONFIRMED" : "FAILED"): \(v6value)")
    }
}

// V7: Closure-based peek
do {
    var v7box = V7Box(Resource(77))
    let v7result = v7box.peek { $0.value }
    print("V7: Closure-based peek — \(v7result == 77 ? "CONFIRMED" : "FAILED"): \(v7result ?? -1)")
}

// V3: Optional<Span> function
do {
    let values = [10, 20, 30]
    let empty: [Int] = []
    if let span = optionalSpan(values) {
        print("V3: Function Optional<Span> non-empty — CONFIRMED: \(span[0])")
    }
    if optionalSpan(empty) == nil {
        print("V3: Function Optional<Span> nil — CONFIRMED")
    }
}

// V4: Optional<Span> property
do {
    let full = V4Container(_values: [10, 20, 30])
    let empty = V4Container(_values: [])
    if let span = full.optionalSpan {
        print("V4: Property Optional<Span> non-empty — CONFIRMED: \(span[0])")
    }
    if empty.optionalSpan == nil {
        print("V4: Property Optional<Span> nil — CONFIRMED")
    }
}

// V5: _read yielding Optional<Borrowed<Resource>>
do {
    var v5box = V5Box(Resource(55))
    if let front = v5box.front {
        let val = front.pointee.value
        print("V5: _read Optional<Borrowed> non-empty — CONFIRMED: \(val)")
    }
    // Test nil path: make empty by popping
    v5box._count = 0
    unsafe v5box._storage.deinitialize(count: 1)
    if v5box.front == nil {
        print("V5: _read Optional<Borrowed> nil — CONFIRMED")
    }
}
