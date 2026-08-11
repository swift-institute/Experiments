// MutableLinchpin — the mutable span-vending capability with the `MutableSpan` linchpin.
//
// The mutable capability protocol RESTATES `~Escapable` (today's `Span.Mutable.Protocol`
// does not — it is owned-only). Restating it admits `~Escapable` conformers (a bare
// `Swift.MutableSpan`) WITHOUT affecting the owned (Escapable) conformers — suppression
// admits both regimes, exactly as the read `Span.Protocol` already does.
//
// The linchpin: a bare `Swift.MutableSpan` vends ITSELF as its mutable span. This is the
// novel, soundness-uncertain step. `main` exercises it cross-module to check that the
// self-vend aliases the backing storage (so mutations are observed), in release mode.

/// Read capability (mirrors `Span.Protocol`).
public protocol __Span_Protocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    var span: Swift.Span<Element> { @_lifetime(borrow self) get }
}

/// Mutable refinement — `~Escapable` RESTATED so a borrowed `MutableSpan` may conform.
public protocol __Span_Mutable_Protocol: __Span_Protocol, ~Copyable, ~Escapable {
    var mutableSpan: Swift.MutableSpan<Element> { @_lifetime(&self) mutating get }
}

// Linchpin: `Swift.MutableSpan` IS the mutable span-vending capability — it vends itself.
// (`span`, the inherited read requirement, is satisfied by MutableSpan's native `.span`.)
//
// NOTE: a naive `mutating get { self }` does NOT compile — returning `self` CONSUMES the
// `~Copyable` MutableSpan, leaving the `inout self` uninitialized. The sound form re-borrows
// via `extracting(...)` (the full-range, non-consuming `mutating func`), which returns a
// MutableSpan over self's storage tied to the `&self` borrow.
extension Swift.MutableSpan: __Span_Mutable_Protocol {
    @inlinable public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self) mutating get { extracting(...) }
    }
}
