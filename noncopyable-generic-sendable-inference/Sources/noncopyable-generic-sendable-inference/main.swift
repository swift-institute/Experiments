// MARK: - ~Copyable Generic Blocks Sendable Inference on Classes
//
// Purpose: The swift-ownership-primitives documentation for
//   `Ownership.Shared` (final class) and `Ownership.Unique` (~Copyable
//   struct) both justify `@unsafe @unchecked Sendable` with the claim
//   "~Copyable generic parameters [in class storage / on ~Copyable
//   structs] prevent structural Sendable inference."
//
//   This experiment validates that claim on Swift 6.3.1 by declaring
//   structurally-identical types as plain `Sendable` (no `@unchecked`)
//   and observing whether the compiler accepts or rejects the
//   conformance.
//
//   Per [MEM-SEND-004] (memory-safety skill), "~Copyable structs whose
//   stored properties are all Sendable MUST use plain Sendable, not
//   @unchecked Sendable." If that's live on 6.3.1, the Ownership.Unique
//   @unchecked annotation is stale. But the rule explicitly covers
//   structs; classes with ~Copyable generic might still have the gap.
//
// Hypothesis:
//   V1 (class + Sendable-constrained ~Copyable generic + immutable payload):
//     STILL PRESENT — compiler rejects plain Sendable.
//   V2 (~Copyable struct + Sendable-constrained ~Copyable generic):
//     FIXED — compiler accepts plain Sendable per [MEM-SEND-004].
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: FIXED (verified 2026-04-23)
//
// Result: FIXED — V1 HYPOTHESIS REFUTED.
//
//   V1 (PlainSharedClass — final class with ~Copyable & Sendable generic
//       and `let value: Value`): compiles and runs with plain `Sendable`.
//       No `@unchecked` needed.
//
//   V2 (PlainUniqueStructNoPointer — ~Copyable struct with ~Copyable &
//       Sendable generic and Int stored state): compiles and runs with
//       plain `Sendable`. Confirms [MEM-SEND-004] applies.
//
//   V2b (commented-out — ~Copyable struct with UnsafeMutablePointer<Value>?
//        storage): FAILS with "stored property '_storage' of 'Sendable'-
//        conforming generic struct has non-Sendable type
//        'UnsafeMutablePointer<Value>?'". The blocker is the pointer
//        storage itself (non-Sendable by @unsafe _Pointer conformance),
//        NOT the ~Copyable generic.
//
//   V3 baseline: compiles as expected.
//
// Implications for swift-ownership-primitives:
//
//   - Ownership.Shared: `@unsafe @unchecked Sendable` is STALE — drop
//     the `@unchecked` and use plain `Sendable`. The `~Copyable generic
//     blocks Sendable inference` claim in the doc comment is no longer
//     accurate on 6.3.1.
//
//   - Ownership.Unique: `@unsafe @unchecked Sendable` is STILL
//     NECESSARY, but the doc justification should be updated — the
//     blocker is `UnsafeMutablePointer<Value>?` storage being
//     non-Sendable, not the ~Copyable generic parameter.
//
//   - Ownership.Transfer._Box / Box.Pointer / Slot: have atomic state
//     machines or raw pointer storage; @unchecked is Category A
//     (synchronized) or storage-driven, unchanged by this finding.

// ============================================================================
// MARK: - V1: final class with ~Copyable Sendable-constrained generic
//
// Models `Ownership.Shared`. If the compiler accepts plain `Sendable`,
// the @unchecked annotation on Ownership.Shared is obsolete.
// ============================================================================

public final class PlainSharedClass<Value: ~Copyable & Sendable>: Sendable {
    public let value: Value

    public init(_ value: consuming Value) {
        self.value = value
    }
}

// ============================================================================
// MARK: - V2: ~Copyable struct with ~Copyable Sendable-constrained generic
//            and Int-only stored state (excluding UnsafeMutablePointer)
//
// Models the *structural* shape of `Ownership.Unique` minus the
// UnsafeMutablePointer storage, to isolate whether the ~Copyable
// generic parameter itself blocks Sendable inference.
// ============================================================================

public struct PlainUniqueStructNoPointer<Value: ~Copyable & Sendable>: ~Copyable, Sendable {
    @usableFromInline
    internal let identifier: Int

    @inlinable
    public init(_ identifier: Int) {
        self.identifier = identifier
    }
}

// ============================================================================
// MARK: - V2b: ~Copyable struct with UnsafeMutablePointer storage
//
// Matches Ownership.Unique's real shape. The blocker is NOT the
// ~Copyable generic — it's that `UnsafeMutablePointer<Value>` is itself
// non-Sendable (per stdlib's @unsafe conformance to _Pointer). Uncomment
// to see the exact diagnostic on 6.3.1:
//
//   error: stored property '_storage' of 'Sendable'-conforming generic
//   struct 'PlainUniqueStructWithPointer' has non-Sendable type
//   'UnsafeMutablePointer<Value>?'
//
// Interpretation: Ownership.Unique's `@unchecked Sendable` is justified
// by the pointer storage, not by the ~Copyable generic.
// ============================================================================

// public struct PlainUniqueStructWithPointer<Value: ~Copyable & Sendable>: ~Copyable, Sendable {
//     @usableFromInline
//     internal var _storage: UnsafeMutablePointer<Value>?
//
//     @inlinable
//     public init(_ value: consuming Value) {
//         let storage = UnsafeMutablePointer<Value>.allocate(capacity: 1)
//         unsafe storage.initialize(to: value)
//         unsafe (self._storage = storage)
//     }
//
//     deinit {
//         if let storage = unsafe _storage {
//             unsafe storage.deinitialize(count: 1)
//             unsafe storage.deallocate()
//         }
//     }
// }

// ============================================================================
// MARK: - V3 baseline — plain Sendable class without ~Copyable generic (control)
//
// Confirms the compiler does accept plain Sendable on the "normal" shape.
// ============================================================================

public final class PlainBaselineClass<Value: Sendable>: Sendable {
    public let value: Value

    public init(_ value: consuming Value) {
        self.value = value
    }
}

// ============================================================================
// MARK: - Exercise
// ============================================================================

struct Payload: Sendable {
    let id: Int
}

let shared: PlainSharedClass<Payload> = PlainSharedClass(Payload(id: 1))
print("V1 shared.value.id = \(shared.value.id)")

func exerciseV2() {
    let uniqueNoPtr = PlainUniqueStructNoPointer<Payload>(2)
    _ = consume uniqueNoPtr
    print("V2 no-pointer shape constructed and consumed")
}
exerciseV2()

let baseline = PlainBaselineClass(Payload(id: 3))
print("V3 baseline.value.id = \(baseline.value.id)")
