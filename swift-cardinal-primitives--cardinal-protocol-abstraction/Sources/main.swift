// MARK: - Cardinal.Protocol Abstraction Experiment
// Purpose: Verify that a Cardinal.Protocol can abstract over both
//          Cardinal and Tagged<_, Cardinal>, enabling generic operations
//          (like alignment) to accept either without rawValue extraction.
//
// Hypothesis: A protocol with `cardinal` property and `init(cardinal:)`
//             requirement can be conditionally conformed to by Tagged,
//             and generic functions preserve the concrete return type.
//
// Note: init(cardinal:) uses a label to avoid collision with Cardinal's
//       existing init(_ value: UInt). Unlabeled init(_: Cardinal) would
//       conflict at the witness level.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — all 5 variants pass. Build Succeeded, runtime correct.
// Date: 2026-02-04

// ============================================================================
// Minimal reproductions of the relevant types
// ============================================================================

struct Cardinal: Sendable, Hashable, Comparable {
    let rawValue: UInt

    init(_ value: UInt) {
        self.rawValue = value
    }

    static var zero: Self { Self(0) }
    static var one: Self { Self(1) }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable {
    var _storage: RawValue

    var rawValue: RawValue {
        _read { yield _storage }
        _modify { yield &_storage }
    }

    init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self._storage = rawValue
    }
}

extension Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable {}
extension Tagged: Sendable where Tag: ~Copyable, RawValue: ~Copyable & Sendable {}
extension Tagged: Equatable where Tag: ~Copyable, RawValue: Equatable {}
extension Tagged: Hashable where Tag: ~Copyable, RawValue: Hashable {}
extension Tagged: Comparable where Tag: ~Copyable, RawValue: Comparable {
    static func < (lhs: Tagged, rhs: Tagged) -> Bool {
        lhs._storage < rhs._storage
    }
}

// ============================================================================
// MARK: - Variant 1: Cardinal.Protocol definition
// Hypothesis: A protocol nested in Cardinal can require cardinal access
//             and construction, and Cardinal itself conforms trivially.
// Result: CONFIRMED — compiles, Cardinal self-conformance works
// ============================================================================

extension Cardinal {
    protocol `Protocol` {
        var cardinal: Cardinal { get }
        init(cardinal: Cardinal)
    }
}

extension Cardinal: Cardinal.`Protocol` {
    var cardinal: Cardinal { self }

    init(cardinal: Cardinal) {
        self = cardinal
    }
}

// ============================================================================
// MARK: - Variant 2: Tagged conditional conformance
// Hypothesis: Tagged<Tag, Cardinal> can conditionally conform to
//             Cardinal.Protocol where RawValue == Cardinal, Tag: ~Copyable.
// Result: CONFIRMED — conditional conformance compiles
// ============================================================================

extension Tagged: Cardinal.`Protocol` where RawValue == Cardinal, Tag: ~Copyable {
    var cardinal: Cardinal { rawValue }

    init(cardinal: Cardinal) {
        self.init(__unchecked: (), cardinal)
    }
}

// ============================================================================
// MARK: - Variant 3: Generic function over Cardinal.Protocol
// Hypothesis: A generic function constrained to Cardinal.Protocol
//             accepts both Cardinal and Tagged<_, Cardinal>, and
//             the return type is preserved (type-preserving round-trip).
// Result: CONFIRMED — both types accepted, correct values
//   Output: Variant 3a — Cardinal:        input=5000, aligned=8192
//   Output: Variant 3b — Tagged<Cardinal>: input=5000, aligned=8192
// ============================================================================

/// Simulates Memory.Alignment.Align.up — rounds up to 4096 boundary.
func alignUp<C: Cardinal.`Protocol`>(_ value: C) -> C {
    let shift: UInt = 12 // 4096
    let mask: UInt = (1 << shift) - 1
    return C(cardinal: Cardinal((value.cardinal.rawValue &+ mask) & ~mask))
}

// Test with bare Cardinal
let bare = Cardinal(5000)
let bareAligned = alignUp(bare)
print("Variant 3a — Cardinal:        input=\(bare.rawValue), aligned=\(bareAligned.rawValue)")

// Test with Tagged<_, Cardinal>
enum StorageTag {}
typealias StorageCount = Tagged<StorageTag, Cardinal>

let tagged = StorageCount(__unchecked: (), Cardinal(5000))
let taggedAligned = alignUp(tagged)
print("Variant 3b — Tagged<Cardinal>: input=\(tagged.rawValue.rawValue), aligned=\(taggedAligned.rawValue.rawValue)")

// ============================================================================
// MARK: - Variant 4: Static properties via protocol
// Hypothesis: Cardinal.Protocol conformers can use .zero and .one
//             in generic contexts (needed for the $0 == .zero ? .one : $0 pattern).
// Result: CONFIRMED — zero guard works, zero input yields 4096
//   Output: Variant 4  — zero guard:      input=0, aligned=4096
// ============================================================================

func alignUpNonZero<C: Cardinal.`Protocol` & Equatable>(_ value: C) -> C {
    let effective = value == C(cardinal: .zero) ? C(cardinal: .one) : value
    return alignUp(effective)
}

let zeroTagged = StorageCount(__unchecked: (), Cardinal.zero)
let nonZeroAligned = alignUpNonZero(zeroTagged)
print("Variant 4  — zero guard:      input=\(zeroTagged.rawValue.rawValue), aligned=\(nonZeroAligned.rawValue.rawValue)")

// ============================================================================
// MARK: - Variant 5: Type preservation proof
// Hypothesis: The return type of alignUp<C>(_ value: C) -> C is
//             statically resolved — Tagged in, Tagged out.
// Result: CONFIRMED — taggedAligned accepted by function requiring StorageCount
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   Output: Variant 5  — type preserved:  8192
// ============================================================================

func acceptsOnlyStorageCount(_ count: StorageCount) {
    print("Variant 5  — type preserved:  \(count.rawValue.rawValue)")
}

// This line proves the return type is StorageCount, not Cardinal.
// If type weren't preserved, this would be a compile error.
acceptsOnlyStorageCount(taggedAligned)

// ============================================================================
// MARK: - Results Summary
// ============================================================================
// V1: CONFIRMED — Cardinal.Protocol definition compiles
// V2: CONFIRMED — Tagged conditional conformance compiles
// V3: CONFIRMED — Generic function accepts both, correct arithmetic
// V4: CONFIRMED — Zero-guard pattern works in generic context
// V5: CONFIRMED — Return type statically preserved (compile-time proof)
//
// Key finding: init(cardinal:) MUST use a label. Unlabeled init(_: Cardinal)
// collides with Cardinal's existing init(_ value: UInt) at the witness level.
