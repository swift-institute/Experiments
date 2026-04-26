// Cross-module library exposing the Mutable protocol + four-quadrant
// trivial-self defaults. Mirrors the production package's surface so the
// consumer target probes the same boundary that real downstream packages
// will cross.

public protocol Mutable<Value>: ~Copyable, ~Escapable {
    associatedtype Value: ~Copyable & ~Escapable

    var value: Value {
        @_lifetime(borrow self)
        borrowing get
        set
    }
}

extension Mutable where Value == Self {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

extension Mutable where Value == Self, Self: ~Copyable {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

extension Mutable where Value == Self, Self: ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}

extension Mutable where Value == Self, Self: ~Copyable & ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}
