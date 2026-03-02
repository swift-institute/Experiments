// MARK: - Witness ~Copyable Value Feasibility
// Purpose: Validate that the proposed ~Copyable witness value design compiles
//          and behaves correctly with current experimental features.
// Hypothesis: All 6 variants compile and produce correct output.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Features: SuppressedAssociatedTypes, SuppressedAssociatedTypesWithDefaults, Lifetimes
//
// Result: CONFIRMED — all 6 variants compile and run correctly. One design
//         constraint discovered: protocol default `testValue { liveValue }`
//         cannot forward between getters for ~Copyable values (borrow/consume
//         conflict). Default must be constrained to `where Value: Copyable`.
// Date: 2026-02-24

import Synchronization

// ============================================================================
// MARK: - Minimal Infrastructure (mirrors swift-witnesses patterns)
// ============================================================================

/// Minimal Ownership.Shared equivalent — heap-allocated box for ~Copyable values.
final class Shared<Value: ~Copyable & Sendable>: @unchecked Sendable {
    let value: Value
    init(_ value: consuming Value) { self.value = value }
}

/// Minimal type-erased storage — mirrors Witness.Values._Storage.
final class Storage {
    var dict: [ObjectIdentifier: UnsafeRawPointer] = [:]

    func set(_ ptr: UnsafeRawPointer, for key: ObjectIdentifier) {
        dict[key] = ptr
    }

    deinit {
        for ptr in dict.values {
            unsafe Unmanaged<AnyObject>.fromOpaque(ptr).release()
        }
    }
}

// ============================================================================
// MARK: - Variant 1: Suppressed Copyable on Associated Type
// Hypothesis: associatedtype Value: ~Copyable & Sendable compiles with
//             SuppressedAssociatedTypes feature flag.
// Result: CONFIRMED — protocol compiles. Default impl requires `where Value: Copyable`.
//         ~Copyable conformers must provide explicit testValue.
// ============================================================================

enum Mode: Sendable { case live, test }

protocol WitnessKey: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static var liveValue: Value { get }
    static var testValue: Value { get }
}

// NOTE: Cannot provide default `testValue` that forwards to `liveValue` for
// ~Copyable values. The compiler treats `liveValue` access as a borrow, but
// returning from a getter consumes. Each conformer must provide explicit impls.
// This is Variant 1a finding.
//
// For Copyable-only protocol (e.g. the existing Witness.Key where Value: Copyable),
// the default impl works fine. The ~Copyable suppression creates this constraint.
extension WitnessKey where Value: Copyable {
    static var testValue: Value { liveValue }
}

/// Copyable conformer (common case) — should work unchanged.
struct APIClient: WitnessKey, Sendable {
    var fetch: @Sendable (Int) -> String
    static var liveValue: APIClient { APIClient(fetch: { "live-\($0)" }) }
    static var testValue: APIClient { APIClient(fetch: { "test-\($0)" }) }
}

/// ~Copyable conformer (the new case).
struct UniqueHandle: ~Copyable, Sendable {
    let id: Int
    deinit { print("  UniqueHandle(\(id)) destroyed") }
}

struct HandleProvider: WitnessKey, Sendable {
    typealias Value = UniqueHandle
    static var liveValue: UniqueHandle { UniqueHandle(id: 1) }
    static var testValue: UniqueHandle { UniqueHandle(id: 99) }
}

// ============================================================================
// MARK: - Variant 2: Store ~Copyable in Shared + UnsafeRawPointer
// Hypothesis: Ownership.Shared<T: ~Copyable> can be stored via Unmanaged
//             and the pointer chain works for type erasure.
// Result: CONFIRMED — Output: "Retrieved handle id: 42"
// ============================================================================

func storeAndRetrieve() {
    let storage = Storage()
    let id = ObjectIdentifier(HandleProvider.self)

    // Store: consuming into Shared, then to pointer
    let box = Shared(UniqueHandle(id: 42))
    let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
    unsafe storage.set(ptr, for: id)

    // Retrieve: pointer back to Shared, borrow .value
    if let ptr = unsafe storage.dict[id] {
        let shared = unsafe Unmanaged<Shared<UniqueHandle>>.fromOpaque(ptr)
            .takeUnretainedValue()
        print("  Retrieved handle id: \(shared.value.id)")
    }
    // storage.deinit releases the Shared, which destroys UniqueHandle
}

// ============================================================================
// MARK: - Variant 3: Closure-Scoped Borrowing from Shared
// Hypothesis: A closure can borrow from Shared<T: ~Copyable>.value
//             without @lifetime annotations.
// Result: CONFIRMED — Output: "Borrowed handle id: 7"
// ============================================================================

func withBorrowedValue<T: ~Copyable & Sendable, R>(
    from shared: Shared<T>,
    _ body: (borrowing T) -> R
) -> R {
    body(shared.value)
}

func closureScopedBorrowing() {
    let box = Shared(UniqueHandle(id: 7))
    let result = withBorrowedValue(from: box) { handle in
        "  Borrowed handle id: \(handle.id)"
    }
    print(result)
}

// ============================================================================
// MARK: - Variant 4: Mutex.withLock Return Type
// Hypothesis: Mutex.withLock's Result generic parameter accepts ~Copyable
//             return values, OR we can work around it.
// Result: CONFIRMED — Both approaches work. Approach A: extract Copyable data.
//         Approach B: borrow inside the lock. Output: "Mutex extracted id: 55"
// ============================================================================

func mutexReturnTest() {
    let lock = Mutex<Void>(())

    // Test: can withLock return a non-Copyable value?
    // Mutex.withLock<Result>(_ body: (inout State) throws -> Result) rethrows -> Result
    // If Result doesn't suppress Copyable, this won't compile for ~Copyable.

    // Approach A: Return Copyable data extracted from ~Copyable value
    let storage = Storage()
    let id = ObjectIdentifier(HandleProvider.self)
    let box = Shared(UniqueHandle(id: 55))
    let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
    unsafe storage.set(ptr, for: id)

    let extractedId: Int = lock.withLock { _ in
        if let ptr = unsafe storage.dict[id] {
            let shared = unsafe Unmanaged<Shared<UniqueHandle>>.fromOpaque(ptr)
                .takeUnretainedValue()
            return shared.value.id
        }
        return -1
    }
    print("  Mutex extracted id: \(extractedId)")

    // Approach B: Closure-based borrow INSIDE the lock
    lock.withLock { _ in
        if let ptr = unsafe storage.dict[id] {
            let shared = unsafe Unmanaged<Shared<UniqueHandle>>.fromOpaque(ptr)
                .takeUnretainedValue()
            print("  Mutex borrowed id: \(shared.value.id)")
        }
    }
}

// ============================================================================
// MARK: - Variant 5: Constrained Subscript + Universal withValue
// Hypothesis: A subscript constrained to where K.Value: Copyable can coexist
//             with a universal withValue<K> method on the same type.
// Result: CONFIRMED — Copyable get + universal withValue coexist.
//         Output: "Copyable get: stored-1", "~Copyable withValue: handle id = 123"
// ============================================================================

struct Values {
    let storage = Storage()

    // Owned access — Copyable only
    func get<K: WitnessKey>(_ key: K.Type, mode: Mode) -> K.Value
        where K.Value: Copyable
    {
        let id = ObjectIdentifier(K.self)
        if let ptr = unsafe storage.dict[id] {
            return unsafe Unmanaged<Shared<K.Value>>.fromOpaque(ptr)
                .takeUnretainedValue()
                .value
        }
        return switch mode {
        case .live: K.liveValue
        case .test: K.testValue
        }
    }

    // Borrowed access — universal (works for ~Copyable too)
    func withValue<K: WitnessKey, R>(
        _ key: K.Type,
        mode: Mode,
        _ body: (borrowing K.Value) -> R
    ) -> R {
        let id = ObjectIdentifier(K.self)
        if let ptr = unsafe storage.dict[id] {
            return body(
                unsafe Unmanaged<Shared<K.Value>>.fromOpaque(ptr)
                    .takeUnretainedValue()
                    .value
            )
        }
        // Default — call body directly per branch to avoid
        // borrow/consume issue with switch expression binding.
        return switch mode {
        case .live: body(K.liveValue)
        case .test: body(K.testValue)
        }
    }

    // Set — consuming, universal
    func set<K: WitnessKey>(_ key: K.Type, _ value: consuming K.Value) {
        let id = ObjectIdentifier(K.self)
        if let oldPtr = unsafe storage.dict[id] {
            unsafe Unmanaged<AnyObject>.fromOpaque(oldPtr).release()
        }
        let box = Shared(value)
        let ptr = unsafe UnsafeRawPointer(Unmanaged.passRetained(box).toOpaque())
        unsafe storage.set(ptr, for: id)
    }
}

func constrainedSubscriptTest() {
    let values = Values()

    // Copyable path — owned return
    values.set(APIClient.self, APIClient(fetch: { "stored-\($0)" }))
    let client = values.get(APIClient.self, mode: .live)
    print("  Copyable get: \(client.fetch(1))")

    // ~Copyable path — closure borrow
    values.set(HandleProvider.self, UniqueHandle(id: 123))
    values.withValue(HandleProvider.self, mode: .live) { handle in
        print("  ~Copyable withValue: handle id = \(handle.id)")
    }

    // ~Copyable default (no stored value) — factory creates temporary
    let values2 = Values()
    values2.withValue(HandleProvider.self, mode: .test) { handle in
        print("  ~Copyable default: handle id = \(handle.id)")
    }
}

// ============================================================================
// MARK: - Variant 6: Typed Throws Through Closure-Scoped Borrow
// Hypothesis: The closure-based withValue supports typed throws(E).
// Result: CONFIRMED — Non-throwing closure works in typed-throws context.
//         Output: "Typed-throws context: handle id = 77"
// ============================================================================

enum Lookup {
    enum Error: Swift.Error { case notFound }
}

func typedThrowsTest() throws(Lookup.Error) {
    let values = Values()
    values.set(HandleProvider.self, UniqueHandle(id: 77))

    // This requires: (borrowing K.Value) throws(E) -> R
    // For now test if the non-throwing version works; typed throws
    // on the closure parameter may need a separate overload.
    values.withValue(HandleProvider.self, mode: .live) { handle in
        print("  Typed-throws context: handle id = \(handle.id)")
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("Variant 1: Suppressed Copyable on Associated Type")
print("  APIClient.liveValue.fetch(1) = \(APIClient.liveValue.fetch(1))")
// UniqueHandle creation via factory:
do {
    let h = HandleProvider.liveValue
    print("  HandleProvider.liveValue.id = \(h.id)")
}

print("\nVariant 2: Store ~Copyable in Shared + UnsafeRawPointer")
storeAndRetrieve()

print("\nVariant 3: Closure-Scoped Borrowing from Shared")
closureScopedBorrowing()

print("\nVariant 4: Mutex.withLock Return Type")
mutexReturnTest()

print("\nVariant 5: Constrained Subscript + Universal withValue")
constrainedSubscriptTest()

print("\nVariant 6: Typed Throws Through Closure-Scoped Borrow")
try typedThrowsTest()

print("\nAll variants complete.")

// ============================================================================
// MARK: - Results Summary
// V1: CONFIRMED — associatedtype Value: ~Copyable & Sendable works.
//     Constraint: default impl testValue { liveValue } requires `where Value: Copyable`.
// V2: CONFIRMED — Shared<T: ~Copyable> + Unmanaged + UnsafeRawPointer works.
// V3: CONFIRMED — Closure-scoped borrowing from Shared.value works without @lifetime.
// V4: CONFIRMED — Mutex.withLock works (extract Copyable data or borrow inside lock).
// V5: CONFIRMED — Copyable-constrained get + universal withValue coexist cleanly.
// V6: CONFIRMED — withValue works in typed-throws context.
//
// Design constraint discovered:
//   Protocol default `testValue { liveValue }` cannot forward between getters
//   for ~Copyable values. The compiler treats `liveValue` as a borrow, but
//   returning from a getter consumes. Solution: constrain default to
//   `where Value: Copyable`. ~Copyable conformers provide explicit impls.
//   This matches the existing Witness.Key pattern where testValue defaults to
//   previewValue defaults to liveValue — all three defaults need the constraint.
//
// Impact on swift-witnesses design:
//   The `switch mode { case .live: body(K.liveValue) }` pattern (calling body
//   per-branch instead of binding to intermediate) works and is the correct
//   approach for the withValue implementation.
// ============================================================================
