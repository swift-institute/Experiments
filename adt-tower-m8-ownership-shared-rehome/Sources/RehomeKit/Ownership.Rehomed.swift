// ===----------------------------------------------------------------------===//
//
// adt-tower-m8-ownership-shared-rehome — [EXP-003d]
//
// The re-homed CoW column: a FAITHFUL copy of swift-shared-primitives' top-level
// `Shared<Element, B>` (`Sources/Shared Primitive/Shared.swift`), re-declared as a generic
// struct nested in the REAL `Ownership` namespace via a CROSS-PACKAGE extension. This is the
// M8 (W1.8) mechanism from Research/adt-tower.md §D4.5(b): the column moves onto a name owned by
// swift-ownership-primitives by writing `extension Ownership { public struct … }` FROM THE
// COLUMN'S OWN PACKAGE (permitted namespace extension, not ownership). A non-colliding name
// (`Rehomed`) is used so H1 proves the mechanism without tripping the H2 arity collision.
//
// The struct still wraps `Ownership.Box<B>` — the single [MEM-SAFE-028] drain-box home,
// UNCHANGED. The spike wraps it, never reimplements the drain.
//
// ===----------------------------------------------------------------------===//

public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Index_Primitives
public import Ownership_Primitive
public import Ownership_Box_Primitives

// MARK: - The cross-package namespace re-home (M8(b) mechanism)

extension Ownership {
    /// The CoW column combinator, re-homed into the `Ownership` namespace across a package
    /// boundary. Structurally identical to swift-shared-primitives' `Shared<Element, B>`:
    /// wraps a MOVE-ONLY buffer column in the refcounted `Ownership.Box` and is `Copyable`
    /// exactly when the ELEMENT is copyable (copies share the box until the first mutation
    /// restores uniqueness; `~Copyable`-element instantiations are statically unique).
    @frozen
    public struct Rehomed<
        Element: ~Copyable,
        B: Store.`Protocol` & Buffer.`Protocol` & ~Copyable
    >: ~Copyable where B.Element == Element, B.Count == Index<Element>.Count {

        /// The single refcounted backing (the [MEM-SAFE-028] drain-box, wrapped not reimplemented).
        @usableFromInline
        internal var box: Ownership.Box<B>

        @usableFromInline
        internal init(box: consuming Ownership.Box<B>) {
            self.box = box
        }

        /// Identity of the current backing box — CoW divergence is observable here (test window).
        @usableFromInline
        package var _boxID: ObjectIdentifier { box.identity }
    }
}

// MARK: - Conditional Conformances (mirrors Shared.swift exactly)

/// `Copyable` exactly when `Element` is (the stored property is a class reference — always
/// Copyable-layout — and the struct carries no deinit, so SE-0427 is satisfied; `B` stays
/// explicitly `~Copyable`).
extension Ownership.Rehomed: Copyable where Element: Copyable, B: ~Copyable {}

/// `Sendable` via the CoW discipline: every public mutation restores uniqueness before writing.
extension Ownership.Rehomed: Sendable where Element: ~Copyable, B: Sendable & ~Copyable {}
