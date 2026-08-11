// Status: FIXED -- original SIL-crash hypothesis (synthesized Equatable for nested type in conditional extension of ~Copyable enum) does NOT reproduce on Swift 6.3.1.
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Revalidated: Swift 6.3.1 (2026-04-30) -- FIXED. swift build -c release: clean compile (0.30s); swiftc -O -emit-sil emits 1090 lines with no crash, no "ambiguous use of operator '=='" diagnostic. (Phase 1b stale-triage 2026-04-30)
// Note: Sources/Lib/main.swift renamed to BitPackedCrash.swift to fix package layout (file has no top-level executable code; SwiftPM rejects main.swift in non-executable target).
// Methodological caveat: the original 2026-01-23 Package.swift declared `.target(name: "Lib")` containing main.swift -- a layout SwiftPM has rejected since tools-version 5.4. The original "RESULT: [PENDING]" header almost certainly reflects the author hitting the same package-config error and stopping; the minimal reducer was likely never compiled to SIL by anyone, including under Swift 6.0/6.2.x. The 2026-04-30 FIXED verdict is therefore the FIRST verifiable empirical run of this reducer -- not a re-run that detected a silent fix. Whether the original __derived_struct_equals crash actually reproduced in this minimized shape on any toolchain is unknown.
// ===----------------------------------------------------------------------===//
// Experiment: bit-packed-crash
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Synthesized Equatable for nested type in conditional extension
//             of ~Copyable enum crashes Swift compiler during SIL generation.
//
// TRIGGER: Set<Bit>.Packed.Bounded : Equatable crashes in __derived_struct_equals
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// RESULT: [PENDING]
//
// ===----------------------------------------------------------------------===//

// V1: Minimal ~Copyable enum with conditional extension containing nested type
// Attempt to reproduce the crash

/// A minimal protocol to satisfy the constraint
public protocol P: ~Copyable {
    var hashValue: Int { get }
}

/// A copyable type that conforms to P
public struct Marker: P, Sendable {
    public var hashValue: Int { 0 }
    public init() {}
}

/// ~Copyable namespace enum (like Set<Element>)
public enum Container<Element: P & ~Copyable>: ~Copyable {}

/// Conditional extension (like extension Set where Element == Bit)
extension Container where Element == Marker {
    /// Outer struct (like Set<Bit>.Packed)
    public struct Outer: Sendable {
        public var storage: ContiguousArray<UInt>

        public init() {
            self.storage = []
        }
    }
}

/// Nested type in separate extension (like Set<Bit>.Packed.Bounded)
extension Container<Marker>.Outer {
    public struct Bounded: Sendable {
        public var storage: ContiguousArray<UInt>
        public let capacity: Int

        public init(capacity: Int) {
            self.storage = ContiguousArray(repeating: 0, count: capacity)
            self.capacity = capacity
        }
    }
}

// V1a: Add synthesized Equatable - this is the crash trigger
extension Container<Marker>.Outer.Bounded: Equatable {}
