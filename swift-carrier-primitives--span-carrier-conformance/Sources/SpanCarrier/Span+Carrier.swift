// Span+Carrier.swift
//
// V1 (REFUTED, 2026-04-25): the default trivial-self extension cannot
// witness `Span: Carrier`. Diagnostic: "candidate would match if
// 'Span<Element>' conformed to 'Escapable'". Root cause: the extension
// `Carrier where Underlying == Self` carries Self's default `Escapable`
// constraint — it does not propagate `~Escapable` from the protocol.
// This refutes sli-span-family.md concern #1 in a sharper form than
// anticipated: the failure isn't @_lifetime mismatch on the witness body,
// it's that the witness candidate is excluded from consideration entirely.
//
// V2 (this file): explicit-witness conformance with @_lifetime
// annotations matching the protocol's requirement shape.

extension Span: Carrier {
    public typealias Underlying = Span<Element>

    public var underlying: Span<Element> {
        @_lifetime(borrow self)
        _read { yield self }
    }

    @_lifetime(copy underlying)
    public init(_ underlying: consuming Span<Element>) {
        self = underlying
    }
}
