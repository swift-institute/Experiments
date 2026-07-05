// H2 (negative / ordering probe).
//
// While the 1-generic-parameter `Ownership.Shared<Value>` box CLASS still exists (imported here
// from another module, exactly as swift-shared-primitives imports it from
// swift-ownership-primitives), ALSO declare the 2-parameter CoW-column STRUCT onto the same
// nested name FROM THIS (different) MODULE — the exact hazard if M8(b) (the column move) ran
// before M8(a) (the box rename to `Ownership.Immutable`).
//
// The question this pins: redeclaration error, use-site ambiguity, or clean arity
// disambiguation? The answer determines whether M8(a) rename-first is compiler-FORCED or merely
// hygiene-driven. Compiled with `swiftc -typecheck`; diagnostics captured verbatim to
// Outputs/h2-collision.txt.
import OwnershipBoxStub

extension Ownership {
    public struct Shared<Element: ~Copyable, B: ~Copyable> {
        public init() {}
    }
}
