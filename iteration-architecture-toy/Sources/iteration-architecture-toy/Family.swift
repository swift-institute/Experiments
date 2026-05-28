// MARK: - Phase 2 — Family protocol with `Backing`, three-route defaults
// The family protocol refines Collection.`Protocol` (intrinsic) and carries a `Backing`
// associated type that the iteration delegation routes through ONCE.

public enum MyFamily {}

public extension MyFamily {
    protocol `Protocol`: Collection.`Protocol`, ~Copyable, ~Escapable {
        // Backing is a ~Escapable borrowed VIEW (like `span`), getter @_lifetime(borrow self).
        associatedtype Backing: ~Copyable & ~Escapable
        var backing: Backing { @_lifetime(borrow self) get }
    }
}

// MARK: Shape A — the LIFT (REFUTED #1, verified 2026-05-28, Apple Swift 6.3.2)
// Hypothesis: a protocol extension lifts `Iterable` conformance onto the family protocol so
// every conformer is Iterable for free. REFUTED — exact diagnostic:
//   error: extension of protocol 'Protocol' cannot have an inheritance clause
//     extension MyFamily.`Protocol`: Iterable where Backing: Iterable, ... { ... }
// Swift forbids a protocol gaining conformance via extension; only concrete types or
// (unconditional) refinements may declare conformance.

// MARK: Shape B / B′ — makeIterator DEFAULT via Backing delegation (REFUTED #2, verified)
// Hypothesis: each variant opts into `: Iterable` (one line) but the makeIterator BODY lives
// once here, delegating to backing.makeIterator(). REFUTED for BOTH Backing: ~Copyable (owned)
// AND Backing: ~Copyable & ~Escapable (borrowed view, getter @_lifetime(borrow self)).
// Exact diagnostic:
//   error: lifetime-dependent value escapes its scope
//     backing.makeIterator()  // note: it depends on the lifetime of this parent value
// The returned iterator depends on the TEMPORARY `backing` projection; the compiler does not
// flatten @_lifetime(borrow backing) (where backing is itself @_lifetime(borrow self)) into
// @_lifetime(borrow self). This refutation is SPECIFIC to a BORROW-self backing makeIterator.
// It is RESCUED when the backing is a ~Escapable view with a @_lifetime(COPY self) makeIterator
// — see Phase2Revisit.swift D1 (CONFIRMED, runs): `copy` flattens the dependency where `borrow`
// of a local does not. So makeIterator delegation IS expressible; it just needs copy-lifetime.
//
//   public extension MyFamily.`Protocol`
//       where Self: Iterable, Backing: Iterable,
//             Backing.Element == Element, Backing.Iterator == Self.Iterator {
//       @_lifetime(borrow self)
//       borrowing func makeIterator() -> Self.Iterator { backing.makeIterator() }
//   }

// MARK: Route-3 capability — a borrowing forEach the Backing can vend (internal iteration)
public protocol BorrowForEachable: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    borrowing func forEach(_ body: (borrowing Element) -> Void)
}

// MARK: Shape C — forEach DEFAULT via Backing delegation (route 3, the ~Copyable crux)
// Hypothesis: a borrowing forEach delegates to backing.forEach(body). Because forEach returns
// Void (no escaping lifetime-dependent value), the two-hop lifetime wall that sinks makeIterator
// should NOT apply.
public extension MyFamily.`Protocol`
    where Self: ~Copyable & ~Escapable,
          Backing: BorrowForEachable, Backing.Element == Element {
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        backing.forEach(body)
    }
}
