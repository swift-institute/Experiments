// MARK: - Variant 5: Property.Inout for ~Copyable Pair tier
//
// Purpose: Test whether `Property.Inout.Typed<Element>` (the ~Copyable mut-in-place
//   View variant) can host a type-changing transformation that returns
//   `Pair<NewFirst, Second>` for the ~Copyable Pair tier.
//
// Hypothesis: REFUTED — Property.Inout uses _read+_modify coroutines that yield
//   `inout Base` of the *same* type. A method on Property.Inout cannot return a
//   different-typed Pair from a borrow scope. Additionally, Property.Inout.Typed
//   itself is `~Escapable` per the V2 finding.
//
// Toolchain: Swift 6.3.1 (Apple swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Result: REFUTED
// Diagnostic: main.swift:60:46: error: field 'pair.map' was consumed but not
//   reinitialized; the field must be reinitialized during the access.
//   The `var map: Property<Map>.Inout` accessor uses `mutating _read`/
//   `mutating _modify` yielding a Property.Inout View. A `consuming func first`
//   on the View consumes the View — but the View came from `_modify`'s yield,
//   which expects the inout reference to be returned in the same type. Consuming
//   it destroys the borrow lender, hence "consumed but not reinitialized."
//   This is the structural blocker: borrow scopes cannot produce different-typed
//   returns because the borrow contract requires the reference be live and
//   re-yielded at scope-exit.
// Command: swift build --target variant-5-property-inout
// Date: 2026-05-08

import Pair_Primitives
import Property_Primitives

extension Pair where First: ~Copyable, Second: ~Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Pair<First, Second>>
}

extension Pair where First: ~Copyable, Second: ~Copyable {
    enum Map {}

    var map: Property<Map>.Inout {
        mutating _read { yield Property<Map>.Inout(&self) }
        mutating _modify {
            var view = Property<Map>.Inout(&self)
            yield &view
        }
    }
}

// Attempt: define a method on Property.Inout that returns a different-typed Pair.
// Without a PairLike bridge, we cannot bind Second; with one, ~Copyable
// associatedtypes need the SuppressedAssociatedTypes experimental feature.
// Even granting both, the Inout View borrows base — we can't return a different-typed
// Pair from a borrow scope.

extension Property.Inout
where Tag == Pair<Int, Int>.Map, Base == Pair<Int, Int> {
    // Concrete Pair<Int, Int> to bypass the two-generic / PairLike issue.
    // Tests ONLY whether a method on Property.Inout can return a different-typed Pair.
    consuming func first<NewFirst, E: Error>(
        _ transform: (Int) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Int> {
        // base is `Ownership.Inout<Base>` — exclusive mutable ref.
        // We need to read first/second from base and construct a fresh Pair.
        // base.value yields the underlying Pair via a coroutine.
        let firstVal = base.value.first
        let secondVal = base.value.second
        return try Pair<NewFirst, Int>(transform(firstVal), secondVal)
    }
}

var pair = Pair(7, 42)
do {
    let result: Pair<String, Int> = try pair.map.first { "\($0)" }
    print("V5 first transform: Pair(\(result.first), \(result.second))")
} catch {
    print("V5 first transform: error \(error)")
}
