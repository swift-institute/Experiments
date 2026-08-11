// Carrier.swift — verbatim mirror of swift-carrier-primitives' production
// Carrier protocol, redeclared locally so the experiment is standalone.

public protocol Carrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}
