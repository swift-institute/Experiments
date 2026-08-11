// BoundAlias — the BOUND generic typealias. Kept to show WHY the unbound form is needed.
//
// `typealias Span<Element: ~Copyable> = Swift.Span<Element>` resolves the collision
// (`Span<Byte>` is the stdlib span), but member lookup on a *generic typealias*
// requires specialization: bare `Span.Protocol` does NOT resolve (Counterexample 03),
// only `Span<Int>.Protocol` does — and the `<Int>` is a vacuous phantom (every element
// argument names the same protocol). That phantom breaks the element-agnostic generic
// algorithm spelling, which is why UnboundAlias (Span = Swift.Span) is preferred.

public protocol __Span_Protocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    var span: Swift.Span<Element> { @_lifetime(borrow self) get }
}

public typealias Span<Element: ~Copyable> = Swift.Span<Element>   // <-- BOUND

extension Swift.Span { public typealias `Protocol` = __Span_Protocol }

extension Swift.Span: __Span_Protocol {
    @inlinable public var span: Swift.Span<Element> {
        @_lifetime(borrow self) get { self }
    }
}

// Only the SPECIALIZED spelling compiles here; bare `Span.Protocol` is Counterexample 03.
@inlinable
public func usesSpecialized<T: Span<Int>.`Protocol` & ~Copyable & ~Escapable>(
    _ t: borrowing T
) -> Bool {
    t.span.isEmpty
}
