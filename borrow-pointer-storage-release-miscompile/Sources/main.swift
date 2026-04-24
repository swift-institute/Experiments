// MARK: - Borrow-Pointer Storage Release Miscompile
//
// Purpose: Minimal reproducer for a Swift 6.3 release-mode miscompile where a
//          raw pointer captured via `withUnsafePointer(to: value) { $0 }` and
//          stored in a `~Escapable` wrapper struct produces a dangling pointer
//          the moment `withUnsafePointer`'s frame is popped. The pattern:
//
//              @_lifetime(borrow value)
//              init(borrowing value: borrowing Value) {
//                  self._pointer = withUnsafePointer(to: value) { $0 }
//              }
//
//          Release-mode reads via `self._pointer.pointee` either return
//          garbage pointer-shaped integers or trap on `EXC_BREAKPOINT`
//          (observed on Swift 6.3.1 arm64 macOS 26). Debug-mode reads return
//          the correct value (stale slot happens to still hold the right bits).
//
// Hypothesis (H0): `withUnsafePointer(to: value)` spills `value` into a stack
//          slot within its own frame and passes that slot's address to the
//          closure. After the closure returns the slot dies but the captured
//          address is retained in `self._pointer`. `@_lifetime(borrow value)`
//          does not make the captured slot-address survive — the annotation
//          binds the wrapper's lifetime to `value` but does not change what
//          address `withUnsafePointer` returned.
//
// Context: Reduction of a bug in swift-ownership-primitives where
//          `Ownership.Borrow<Value>.init(borrowing:)` produced 9 release-mode
//          test failures in the `Ownership Borrow Tests` suite and 14 cascaded
//          failures in swift-property-primitives `Property.View.Read` tests
//          (which store `Tagged<Tag, Ownership.Borrow<Base>>`). This
//          reproducer isolates the miscompile from all ecosystem dependencies
//          — only stdlib + `withUnsafePointer`.
//
// Toolchain: swift-6.3.1 (Xcode 26.4.1 default)
// Platform: macOS 26 (arm64)
//
// Status: STILL PRESENT on Swift 6.3.1 AND swift-6.4-dev
//         (swift-DEVELOPMENT-SNAPSHOT-2026-03-16-a).
// Result: CONFIRMED COMPILER BUG, narrow shape:
//
//         Variant verdicts (consolidated across reorderings):
//
//         V5 (heap-owned class, Copyable Value) ....................... PASS
//         V4 (caller-scoped typed init) ............................... PASS
//         V8 (inout + withUnsafeMutablePointer) ....................... PASS
//         V7 (_overrideLifetime + ~Escapable carrier + withUnsafePointer) CRASH
//         V6 (@_addressableForDependencies + withUnsafePointer) ........ CRASH
//         V3 (~Copyable wrapper + withUnsafePointer) ................... CRASH
//         V1 (baseline, ~Copyable Value + withUnsafePointer) ........... CRASH
//         V2 (baseline, Copyable Int + withUnsafePointer) .............. CRASH
//
//         The discriminating pair is V8 vs V1/V7:
//
//         - V8 uses `inout value: inout Value` +
//           `withUnsafeMutablePointer(to: &value) { $0 }` and stores the
//           returned pointer. STABLE — reads succeed in release.
//         - V1/V7 use `borrowing value: borrowing Value` +
//           `withUnsafePointer(to: value) { $0 }` and store the returned
//           pointer. DANGLING — reads return garbage or crash.
//
//         Same storage shape (~Escapable wrapper with a stored typed
//         pointer). Same `@_lifetime(borrow/&value)` annotation style.
//         Only the parameter convention differs. With inout, the caller's
//         address is provided via the inout ABI (indirect, stable); with
//         borrowing, `Builtin.addressOfBorrow` via the ~Copyable overload
//         of `withUnsafePointer` returns a callee-side slot address that
//         dies when the closure returns — even for ~Copyable T where the
//         borrowing ABI is supposed to be @in_guaranteed indirect.
//
//         Neither `_overrideLifetime` on a ~Escapable wrapper (V7) nor
//         `@_addressableForDependencies` on Value (V6) nor `~Copyable`
//         wrapper (V3) rescues the borrowing path. The only safe patterns
//         are caller-scoped typed pointer (V4), heap-owned copy (V5;
//         Copyable only), or inout parameter (V8; not borrowing).
//
//         This rules out a fix inside `Ownership.Borrow.init(borrowing:)`
//         for `~Copyable Value`. The working inout sibling exists as
//         `Ownership.Inout.init(mutating: inout Value)` and is exercised
//         by `Property.View`'s release-passing tests. `Property.View`'s
//         `borrowing` init (@unsafe-marked) mirrors V7's pattern and is
//         likely also broken in release — just not exercised by its
//         tests (the view tests use the inout init).
// Date: 2026-04-24

// MARK: - Shared test value

struct NCValue: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}

// Top-level statements in main.swift execute on the main actor in Swift 6,
// so the counter and the helper both stay main-actor-isolated. No
// `nonisolated(unsafe)` is needed.
var failures = 0

@MainActor
func check(_ name: String, _ got: (Int, Int), expected: (Int, Int)) {
    // Element-wise comparison and element-wise print to avoid any
    // tuple-level surprises in release-mode codegen.
    let g0 = got.0
    let g1 = got.1
    let e0 = expected.0
    let e1 = expected.1
    let pass = (g0 == e0) && (g1 == e1)
    let verdict = pass ? "PASS" : "FAIL"
    if !pass { failures += 1 }
    print("\(name): reads=(\(g0), \(g1)) expected=(\(e0), \(e1)) verdict=\(verdict)")
}

// MARK: - V5: Heap-owning class storage (fix hypothesis for Copyable Value)
//
// Hypothesis: For Copyable Value, copying into a class-owned heap allocation
//             gives the wrapper a stable pointer for its entire lifetime.
//             Class ARC on wrapper copies keeps the allocation alive, and
//             the stored pointer points at heap memory — not a dying stack
//             slot.
// Expected: PASS. This is the production fix already applied in
//           swift-ownership-primitives for the `Copyable Value` path.

final class OwnedBufferV5<Value> {
    @usableFromInline let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    init(copying value: consuming Value) {
        self._pointer = unsafe UnsafeMutablePointer<Value>.allocate(capacity: 1)
        unsafe self._pointer.initialize(to: value)
    }

    @inlinable
    deinit {
        unsafe _pointer.deinitialize(count: 1)
        unsafe _pointer.deallocate()
    }
}

@safe
struct BorrowV5<Value>: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer
    @usableFromInline let _owner: AnyObject

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Value) {
        let owner = OwnedBufferV5<Value>(copying: copy value)
        unsafe (self._pointer = UnsafeRawPointer(owner._pointer))
        self._owner = owner
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

print("--- starting V5 ---")
do {
    let source = 42
    func peek(_ value: borrowing Int) -> (Int, Int) {
        let ref = BorrowV5(borrowing: value)
        return (ref.value, ref.value)
    }
    check("V5 (heap-owned class, Copyable Int)", peek(source), expected: (42, 42))
}

// MARK: - V4: Caller-scoped typed pointer init (workaround pattern)
//
// Hypothesis: Having the caller wrap `withUnsafePointer` at their own scope
//             and passing `UnsafePointer<Value>` into the wrapper keeps the
//             pointer valid for the entire closure body — reads performed
//             inside the closure succeed.
// Expected: PASS. This is the safe-by-construction pattern; the experiment
//           proves it works, justifying a caller-side workaround while the
//           compiler bug persists.

@safe
struct BorrowV4<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow pointer)
    init(_ pointer: UnsafePointer<Value>) {
        unsafe (self._pointer = UnsafeRawPointer(pointer))
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

print("--- starting V4 ---")
do {
    let source = NCValue(42)
    let (a, b) = unsafe withUnsafePointer(to: source) { ptr in
        let ref = BorrowV4(ptr)
        let a = ref.value.x
        let b = ref.value.x
        return (a, b)
    }
    check("V4 (caller-scoped typed init)", (a, b), expected: (42, 42))
}

// MARK: - V6 (disabled): @_addressableForDependencies crashes regardless;
//         commented out so V7 gets to run.
#if false
// MARK: - V6: @_addressableForDependencies on the Value type (fix hypothesis)
//
// Hypothesis: Marking the wrapper's Value generic parameter (or the wrapper
//             struct itself) with @_addressableForDependencies tells the
//             compiler the `borrowing` parameter must be addressable —
//             forcing indirect passing and giving `withUnsafePointer` a
//             stable caller address. (Direction #3 from the handoff brief.)
// Expected: Unknown — testing whether this underscored attribute survives
//           the spill-and-capture pattern.

@_addressableForDependencies
struct NCValueAddressable: ~Copyable {
    var x: Int
    init(_ x: Int) { self.x = x }
}

@safe
struct BorrowV6: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing NCValueAddressable) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: NCValueAddressable {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: NCValueAddressable.self).pointee
        }
    }
}

print("--- starting V6 ---")
do {
    let source = NCValueAddressable(42)
    func peek(_ value: borrowing NCValueAddressable) -> (Int, Int) {
        let ref = BorrowV6(borrowing: value)
        let a = ref.value.x
        let b = ref.value.x
        return (a, b)
    }
    check("V6 (@_addressableForDependencies Value)", peek(source), expected: (42, 42))
}
#endif

print("--- starting V8 ---")
do {
    var source = NCValue(42)
    let ref = BorrowV8(mutating: &source)
    let a = ref.value.x
    let b = ref.value.x
    check("V8 (inout + withUnsafeMutablePointer)", (a, b), expected: (42, 42))
}

print("--- starting V9 ---")
do {
    let source = NCValue(42)
    func peek(_ value: borrowing NCValue) -> (Int, Int) {
        let ref = BorrowV9(value)
        let a = unsafe ref.pointerValue.pointee.x
        let b = unsafe ref.pointerValue.pointee.x
        return (a, b)
    }
    check("V9 (pre-WIP shape: pointer getter + non-inlinable init)",
          peek(source), expected: (42, 42))
}

// MARK: - (V9 runs above; V7 crashes below)
// MARK: - V7: _overrideLifetime on a ~Escapable inner wrapper (fix hypothesis)
//
// Hypothesis: Wrap the stored pointer in an internal `~Escapable` carrier
//             type, then apply `_overrideLifetime(inner, borrowing: value)`
//             to re-tie the carrier's lifetime to `value`. This mirrors the
//             pattern in `Property.View` (mutable sibling), whose release
//             tests pass — it stores `Tagged<Tag, Ownership.Inout<Base>>`
//             (which is `~Escapable` because Inout is `~Escapable`) and
//             applies `_overrideLifetime` to the tagged composition.
//             The handoff brief's earlier finding that `_overrideLifetime`
//             was "a no-op" applied to `UnsafeRawPointer` (Escapable);
//             applying it to a `~Escapable` container is a different
//             operation and is expected to carry the lifetime dependency.
// Expected: PASS. If this works, it is the structural fix — the library
//           can compose the compiler's lifetime machinery the same way
//           `Property.View` already does.

@usableFromInline
struct _BorrowCarrierV7<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    @_lifetime(borrow pointer)
    init(_ pointer: UnsafeMutablePointer<Value>) {
        unsafe (self._pointer = pointer)
    }
}

@safe
struct BorrowV7<Value: ~Copyable>: ~Escapable {
    @usableFromInline var _storage: _BorrowCarrierV7<Value>

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Value) {
        let ptr = unsafe UnsafeMutablePointer<Value>(
            mutating: withUnsafePointer(to: value) { unsafe $0 }
        )
        let carrier = unsafe _BorrowCarrierV7<Value>(ptr)
        self._storage = unsafe _overrideLifetime(carrier, borrowing: value)
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _storage._pointer.pointee
        }
    }
}

print("--- starting V7 ---")
do {
    let source = NCValue(42)
    let ref = BorrowV7(borrowing: source)
    let a = ref.value.x
    let b = ref.value.x
    check("V7 (~Escapable carrier + _overrideLifetime, inline)", (a, b), expected: (42, 42))
}

// MARK: - V8: inout pattern via withUnsafeMutablePointer
//
// Hypothesis: `withUnsafeMutablePointer(to: &value)` with an inout parameter
//             returns the caller's address reliably (inout ABI is always
//             @inout / indirect). This mirrors Ownership.Inout.init(mutating:)
//             which is exercised by Property.View's inout init and passes
//             release tests. If V8 passes while V1 crashes, we know the
//             specific issue is `withUnsafePointer(to: borrowing value)`
//             vs `withUnsafeMutablePointer(to: &value)`.
// Expected: PASS. inout has a stable ABI; spill-slot issue does not arise.

@safe
struct BorrowV8<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeMutablePointer<Value>

    @inlinable
    @_lifetime(&value)
    init(mutating value: inout Value) {
        unsafe (self._pointer = withUnsafeMutablePointer(to: &value) { unsafe $0 })
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.pointee
        }
    }
}

// (V8 execution moved above, before V7, to sidestep V7's crash.)

// MARK: - V9: Pre-WIP Property.View.Read shape (direct UnsafePointer<Base>)
//
// Hypothesis: The pre-WIP `Property.View.Read` stored `UnsafePointer<Base>`
//             directly and called `withUnsafePointer(to: base) { $0 }` in
//             its borrowing init — the same pattern V1/V7 crash on, just
//             without the Ownership.Borrow intermediary. If the compiler
//             bug is a general property of `borrowing + withUnsafePointer`,
//             V9 should also crash. If V9 PASSES, the bug is narrower and
//             tied specifically to storing a raw-untyped pointer (V1) or
//             layering through a ~Escapable carrier (V7) rather than a
//             typed `UnsafePointer<Value>` stored directly.
// Expected: Unknown. This is the key hypothesis — was the pre-WIP design
//           actually working, or was it also broken but uncaught?

@safe
struct BorrowV9<Value: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _pointer: UnsafePointer<Value>

    // Typed-pointer init (analogue of pre-WIP's `init(_:UnsafePointer<Base>)`).
    @inlinable
    @_lifetime(borrow pointer)
    init(_ pointer: UnsafePointer<Value>) {
        unsafe (self._pointer = pointer)
    }

    // Borrowing init — NOT @inlinable, matching pre-WIP exactly.
    @_lifetime(borrow value)
    init(_ value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { unsafe $0 })
    }

    // Plain getter returning the pointer (mirroring pre-WIP's
    // `var base: UnsafePointer<Base> { _base }`) — NOT a _read coroutine.
    @inlinable
    var pointerValue: UnsafePointer<Value> {
        unsafe _pointer
    }
}

// (V9 execution moved to right after V8, before V7.)

// MARK: - V3: ~Copyable wrapper (fix hypothesis: prevent rematerialization)
//
// Hypothesis: Making the wrapper `~Copyable` prevents the optimizer from
//             rematerializing the init on each `.value` read. If the
//             miscompile is rematerialization-driven (i.e. the let-binding
//             is redundantly re-evaluated per access), making the wrapper
//             `~Copyable` stabilises reads.
// Expected: Unknown — this is the hypothesis being tested. If V3 PASSes
//           while V1 crashes on the same Value shape, rematerialization is
//           the driver. If V3 also crashes, the bug is pure
//           dangling-pointer-after-init.

@safe
struct BorrowV3<Value: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

print("--- starting V3 ---")
do {
    let source = NCValue(42)
    func peek(_ value: borrowing NCValue) -> (Int, Int) {
        let ref = BorrowV3(borrowing: value)
        let a = ref.value.x
        let b = ref.value.x
        return (a, b)
    }
    check("V3 (~Copyable wrapper, ~Copyable Value)", peek(source), expected: (42, 42))
}

// MARK: - V1: Baseline — ~Copyable Value + Copyable ~Escapable wrapper
//
// Hypothesis: H0 reproduces for `~Copyable Value`. The `~Copyable`
//             overload of `withUnsafePointer` uses
//             `Builtin.addressOfBorrow(value)`, which for trivial cases
//             still materialises a callee-side slot address. The stored
//             pointer is dangling post-init.
// Expected: FAIL or CRASH in release mode.

@safe
struct BorrowV1<Value: ~Copyable>: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Value) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: Value {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Value.self).pointee
        }
    }
}

print("--- starting V1 ---")
do {
    let source = NCValue(42)
    func peek(_ value: borrowing NCValue) -> (Int, Int) {
        let ref = BorrowV1(borrowing: value)
        let a = ref.value.x
        let b = ref.value.x
        return (a, b)
    }
    check("V1 (~Copyable Value, Copyable wrapper)", peek(source), expected: (42, 42))
}

// MARK: - V2: Baseline — Copyable Int + Copyable ~Escapable wrapper
//
// Hypothesis: Same miscompile manifests for `Copyable` trivial Value (Int).
//             The bug is in the pattern (storing withUnsafePointer's
//             returned address), not the Value's copyability.
// Expected: FAIL or CRASH in release mode.

@safe
struct BorrowV2: ~Escapable {
    @usableFromInline let _pointer: UnsafeRawPointer

    @inlinable
    @_lifetime(borrow value)
    init(borrowing value: borrowing Int) {
        unsafe (self._pointer = withUnsafePointer(to: value) { UnsafeRawPointer($0) })
    }

    @inlinable
    var value: Int {
        _read {
            yield unsafe _pointer.assumingMemoryBound(to: Int.self).pointee
        }
    }
}

print("--- starting V2 ---")
do {
    let source = 42
    func peek(_ value: borrowing Int) -> (Int, Int) {
        let ref = BorrowV2(borrowing: value)
        return (ref.value, ref.value)
    }
    check("V2 (Copyable Int, Copyable wrapper)", peek(source), expected: (42, 42))
}

// MARK: - Summary

print("")
print("===== Summary =====")
print("failures: \(failures)/5 variants")
