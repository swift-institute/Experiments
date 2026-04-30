// MARK: - Static Stored Properties in Generic Types
//
// Purpose: Validate whether Swift 6.3.1 allows `static let` / `static var`
//   stored properties in generic types. swift-ownership-primitives has two
//   workarounds (Ownership.Slot.__OwnershipSlotState and
//   Ownership.Transfer._Box.__OwnershipTransferBoxState) that hoist the
//   state-machine constants to module scope to sidestep this restriction.
//   If the restriction has been lifted, both hoists can be moved back into
//   the respective generic class as nested enums.
//
// Hypothesis: STILL PRESENT on Swift 6.3.1. The restriction is fundamental
//   (generic types have no single, canonical specialisation where a static
//   constant can be stored) and unlikely to change without language-level
//   compromise.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Status: STILL PRESENT (verified 2026-04-23)
//
// Result: STILL PRESENT — V1 uncommented produces the exact diagnostic
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         "error: static stored properties not supported in generic types"
//         (main.swift:31:23). Variants V2–V4 follow the same pattern.
//         V5 baseline (non-generic class) compiles and runs — printing
//         `Baseline non-generic: empty=0, initializing=1, full=2`.
//
//         Decision: keep the hoisted `__OwnershipSlotState` and
//         `__OwnershipTransferBoxState` enums in swift-ownership-primitives.
//         Revisit when Swift gains static-stored-in-generic support.

// ============================================================================
// MARK: - V1: static let stored in generic class
// Uncomment to verify — expected: "static stored properties not supported in generic types"
//
// Verified 2026-04-23 on Swift 6.3.1: STILL PRESENT.
// Exact diagnostic: "error: static stored properties not supported in generic types"
// ============================================================================

// public final class Slot<Value> {
//     public static let empty: UInt8 = 0
// }

// ============================================================================
// MARK: - V2: static var stored in generic class
// Uncomment to verify — expected: same restriction
// ============================================================================

// public final class Slot<Value> {
//     public static var counter: Int = 0
// }

// ============================================================================
// MARK: - V3: static let stored in generic struct
// Uncomment to verify — expected: same restriction
// ============================================================================

// public struct Box<T: ~Copyable>: ~Copyable {
//     public static let initializing: Int = 1
// }

// ============================================================================
// MARK: - V4: Nested enum with static let members in generic outer
// This is the shape we ideally want for Ownership.Slot:
//
//     extension Ownership {
//         public final class Slot<Value: ~Copyable> {
//             public enum State {
//                 public static let empty: UInt8 = 0
//                 public static let initializing: UInt8 = 1
//                 public static let full: UInt8 = 2
//             }
//         }
//     }
//
// Uncomment to verify — expected: static stored properties forbidden inside
// the nested enum because the outer class is generic.
// ============================================================================

// public final class Slot<Value> {
//     public enum State {
//         public static let empty: UInt8 = 0
//     }
// }

// ============================================================================
// MARK: - V5: Baseline — static let in non-generic type (should compile)
// ============================================================================

public final class NonGenericSlot {
    public static let empty: UInt8 = 0
    public static let initializing: UInt8 = 1
    public static let full: UInt8 = 2
}

print("Baseline non-generic: empty=\(NonGenericSlot.empty), initializing=\(NonGenericSlot.initializing), full=\(NonGenericSlot.full)")

// Output when V1–V4 are commented:
//   Baseline non-generic: empty=0, initializing=1, full=2
// Output when V1–V4 are uncommented:
//   error: static stored properties not supported in generic types
