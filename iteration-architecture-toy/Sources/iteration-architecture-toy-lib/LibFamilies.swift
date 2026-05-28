// MARK: - Phase 7 (Gap c) — CROSS-MODULE: family protocols + the three delegating defaults.
// All `public` so the executable module's conformers inherit the bodies across the boundary.

// MARK: FamD — D1 family. Carries a copy-self ~Escapable `View` and the makeIteratorD1 default.
public enum FamD {}
public extension FamD {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype View: ~Copyable & ~Escapable
            where View: IterableByCopy, View.Element == Element
        var view: View { @_lifetime(borrow self) get }
    }
}

// The D1 family default — body lives ONCE in the lib; conformers in the executable inherit it.
public extension FamD.`Protocol` where Self: ~Copyable & ~Escapable {
    @_lifetime(borrow self)
    borrowing func makeIteratorD1() -> View.Iterator {
        view.makeIterator()
    }
}

// MARK: MyFamily — route-3 family. Carries a BorrowForEachable `Backing` and the forEach default (C).
public enum MyFamily {}
public extension MyFamily {
    protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        associatedtype Backing: ~Copyable & ~Escapable
        var backing: Backing { @_lifetime(borrow self) get }
    }
}

// The route-3 forEach family default (C) — delegates to backing.forEach across the module boundary.
public extension MyFamily.`Protocol`
    where Self: ~Copyable & ~Escapable,
          Backing: BorrowForEachable, Backing.Element == Element {
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        backing.forEach(body)
    }
}

// MARK: Route-2 family default — consuming makeIterator owning the consumed Self (generic drain).
public extension Memory.Contiguous
    where Self: ~Copyable, Self: Sequenceable, Element: Copyable,
          Self.Iterator == iteration_architecture_toy_lib.Iterator.Drain<Self> {
    consuming func makeIterator() -> iteration_architecture_toy_lib.Iterator.Drain<Self> {
        iteration_architecture_toy_lib.Iterator.Drain(self)
    }
}
