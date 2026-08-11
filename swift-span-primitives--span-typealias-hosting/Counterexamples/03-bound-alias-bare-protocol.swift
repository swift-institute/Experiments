// Counterexample 03 — why the alias must be UNBOUND.
// Expected: REFUTED — does NOT compile.
//   error: 'Protocol' is not a member type of type 'Span'
//
// With a BOUND generic typealias (`typealias Span<Element> = Swift.Span<Element>`),
// member lookup on the name `Span` requires specialization: `Span<Int>.Protocol`
// resolves, but the BARE `Span.Protocol` does not. The fix is the UNBOUND alias
// `typealias Span = Swift.Span` (see Sources/UnboundAlias) — then `Span` behaves like
// the type name and bare `Span.Protocol` resolves. This file is the bound form, kept
// to demonstrate the failure the unbound form avoids.
//
// Reproduce:
//   swiftc -swift-version 6 -parse-as-library -typecheck \
//     -enable-experimental-feature SuppressedAssociatedTypes 03-bound-alias-bare-protocol.swift

public protocol __Span_Protocol: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    var span: Swift.Span<Element> { @_lifetime(borrow self) get }
}
public typealias Span<Element: ~Copyable> = Swift.Span<Element>   // BOUND — the problem
extension Swift.Span { public typealias `Protocol` = __Span_Protocol }

// Bare, unspecialized member access on the BOUND generic typealias — fails:
func viaBare<T: Span.`Protocol`>(_ t: T) {}
