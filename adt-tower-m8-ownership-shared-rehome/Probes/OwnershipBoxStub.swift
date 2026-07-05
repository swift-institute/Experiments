// Faithful stand-in for swift-ownership-primitives' "Ownership Shared Primitives" TARGET.
//
// The REAL box (Ownership.Shared.swift) is declared EXACTLY as:
//     extension Ownership {
//         public final class Shared<Value: ~Copyable & Sendable>: Sendable { … }
//     }
// This stub reproduces that declaration shape verbatim so the H2 arity-collision mechanic is
// isolated to the two declarations that matter (a 1-param nested class vs a 2-param nested
// struct with the same base name, declared from a DIFFERENT module) without dragging in the
// full primitives graph. The compiler's redeclaration/arity handling is a function of the two
// declaration shapes, not of which package hosts them — so this stub is authoritative for the
// mechanism M8(a)-vs-M8(b) ordering hinges on.
public enum Ownership {}

extension Ownership {
    public final class Shared<Value: ~Copyable & Sendable>: Sendable {
        public let value: Value
        public init(_ value: consuming Value) { self.value = value }
    }
}
