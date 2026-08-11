// UnboundAlias — the CORRECT "hosting + typealias" technique (the validated fix),
// in its "best of all worlds" form.
//
// FOUR ingredients:
//   1. UNBOUND alias `typealias Span = Swift.Span` (no `<Element>`). `Span` then
//      behaves like the type name: `Span<Byte>` is the stdlib read span AND member
//      access `Span.X` resolves WITHOUT specialization.
//   2. `Span.Mutable` aliases the stdlib MUTABLE span: surfaced as the Element-free
//      member typealias `Mutable = Swift.MutableSpan`. So `Span.Mutable<Byte>` IS
//      `Swift.MutableSpan<Byte>` — symmetric with `Span<Byte>`.
//   3. HOST the capability protocols (and Raw) in a single hidden `__Span` namespace
//      (today's `enum Span`, renamed) — a non-generic enum, so it can nest protocols.
//   4. SURFACE each capability as an Element-free member typealias on the matching
//      stdlib type: the read capability on `Swift.Span`, the mutable capability on
//      `Swift.MutableSpan`. So `Span.Protocol` and `Span.Mutable.Protocol` both
//      resolve bare, while `Span<E>` / `Span.Mutable<E>` are the stdlib span types.
//
// Net surface (all bare, no phantom element):
//   Span<E>            == Swift.Span<E>            (read span type)
//   Span.Mutable<E>    == Swift.MutableSpan<E>     (mutable span type)
//   Span.Protocol             — vend-a-read-span capability
//   Span.Mutable.Protocol     — vend-a-mutable-span capability (refines Span.Protocol)
//   Span.Raw                  — the package's Copyable byte-span descriptor (type)
//
// Existing `extension X: Span.Protocol` conformers keep compiling unchanged.

// MARK: - Hidden backing namespace (today's `enum Span`, renamed `__Span`)

public enum __Span {
    public protocol `Protocol`: ~Copyable, ~Escapable {
        associatedtype Element: ~Copyable
        var span: Swift.Span<Element> { @_lifetime(borrow self) get }
    }
    public enum Mutable {
        public protocol `Protocol`: __Span.`Protocol`, ~Copyable {
            var mutableSpan: Swift.MutableSpan<Element> { @_lifetime(&self) mutating get }
        }
    }
    /// Minimal stand-in for the real `Span.Raw` (Copyable, byte-addressed).
    public struct Raw {
        public let count: Int
        public init(count: Int) { self.count = count }
    }
}

// MARK: - The aliases + Element-free surfacing typealiases

public typealias Span = Swift.Span                       // read span (unbound)

extension Swift.Span {
    public typealias `Protocol` = __Span.`Protocol`      // bare Span.Protocol
    public typealias Mutable    = Swift.MutableSpan       // Span.Mutable<E> == MutableSpan<E>
    public typealias Raw        = __Span.Raw             // bare Span.Raw (type position)
}

extension Swift.MutableSpan {
    public typealias `Protocol` = __Span.Mutable.`Protocol`   // bare Span.Mutable.Protocol
}

// MARK: - Linchpin: a Swift.Span vends itself

extension Swift.Span: __Span.`Protocol` {
    @inlinable public var span: Swift.Span<Element> {
        @_lifetime(borrow self) get { self }
    }
}
