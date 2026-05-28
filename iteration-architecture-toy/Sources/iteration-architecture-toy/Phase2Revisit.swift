// MARK: - Phase 2 REVISIT — can makeIterator DELEGATION be rescued? (foundational; get it right)
// Shape B (backing.makeIterator() with Iterable's @_lifetime(borrow self)) escaped because the
// compiler ties the result to the local `view` temporary and won't flatten the two-hop borrow.
// Three rescue hypotheses, tested independently.

// ---------------------------------------------------------------------------------------------
// D1 — COPY-lifetime capability. If the backing's makeIterator is @_lifetime(copy self) and the
// backing is ~Escapable (lifetime = borrow outer-self), `copy` should propagate that dependency
// to the iterator and flatten to @_lifetime(borrow self) — CHECKER-CLEAN (no unsafe).
public protocol IterableByCopy: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: ~Copyable & ~Escapable
        where Iterator: iteration_architecture_toy.Iterator.`Protocol`, Iterator.Element == Element
    @_lifetime(copy self)
    borrowing func makeIterator() -> Iterator
}

public enum FamD {}
public extension FamD {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype View: ~Copyable & ~Escapable
            where View: IterableByCopy, View.Element == Element
        var view: View { @_lifetime(borrow self) get }
    }
}

public extension FamD.`Protocol` where Self: ~Copyable & ~Escapable {
    @_lifetime(borrow self)
    borrowing func makeIteratorD1() -> View.Iterator {
        view.makeIterator()
    }
}

// ---------------------------------------------------------------------------------------------
// D2 — _overrideLifetime. The iterator genuinely DOES borrow self (transitively via view ⊂ self),
// so re-attributing its lifetime to self is TRUE and safe — the same tool the span getter uses.
public enum FamE {}
public extension FamE {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype View: ~Copyable & ~Escapable
            where View: Iterable, View.Element == Element
        var view: View { @_lifetime(borrow self) get }
    }
}

// D2 does NOT work at the family-default level. Through a family-protocol default the backing is
// always a computed `view` GETTER result (a temporary), and an Iterable (`@_lifetime(borrow self)`)
// makeIterator on it escapes BEFORE _overrideLifetime can re-attribute:
//   inline  `_overrideLifetime(view.makeIterator(), borrowing: self)`
//     -> error: lifetime-dependent value escapes its scope (the arg already escaped the temporary)
//   bound   `let v = view; _overrideLifetime(v.makeIterator(), borrowing: self)`
//     -> error: 'self.view' is borrowed and cannot be consumed
// _overrideLifetime works for a STORED projection (the span getter in VariantOwned.swift uses it),
// but not for delegating a borrow-lifetime makeIterator through a computed view. D1 is the rescue.
//
//   public extension FamE.`Protocol` where Self: ~Copyable & ~Escapable {
//       @_lifetime(borrow self)
//       borrowing func makeIteratorD2() -> View.Iterator {
//           _overrideLifetime(view.makeIterator(), borrowing: self)
//       }
//   }

// ---------------------------------------------------------------------------------------------
// D3 — the literal Element-constraint suggestion (where Element: ~Copyable / ~Escapable).
// REFUTED at the constraint itself, before lifetimes even enter: you cannot re-suppress an
// inherited associated type in an extension where-clause. Exact diagnostic:
//   error: cannot suppress '~Copyable' on generic parameter 'Self.Element' defined in outer scope
//     public extension FamE.`Protocol` where ..., Element: ~Copyable { ... }
// (And it would not have helped regardless: the escape is about the ITERATOR's lifetime, not
// the element's copyability/escapability.) So the Element lever is a non-starter; D1/D2 are the
// real rescues.
