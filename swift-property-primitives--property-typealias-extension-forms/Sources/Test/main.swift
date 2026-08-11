// ===----------------------------------------------------------------------===//
// EXPERIMENT: Container-scoped Property<Tag> typealias — which forms work?
// ===----------------------------------------------------------------------===//
//
// QUESTION A: Does the short form `Property<Tag>.View.Typed<Element>.Valued<N>`
//             resolve correctly when used INSIDE a nested tag enum's own
//             `typealias View = ...` declaration?
//
// QUESTION B: Can method extensions be written as
//             `extension Deque.Property where Tag == ..., Base == ...`
//             instead of the canonical
//             `extension Property_Primitives.Property where Tag == ..., Base == ...`?
//
// QUESTION B': Can extensions be written on Deque.Property.Typed — i.e., a
//              nested type reached through a generic typealias?
//
// RESULT (Q-A):  CONFIRMED — short form resolves inside nested tag enum
// RESULT (Q-B):  CONFIRMED — extension on Deque.Property compiles cleanly
// RESULT (Q-B'): REJECTED — extension on Deque.Property.Typed fails:
//                `'Typed' is not a member type of type 'Deque.Property'`
//
// Toolchain: swift 6.2, macOS 26
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ===----------------------------------------------------------------------===//

import Property_Primitives

// ===----------------------------------------------------------------------===//
// MARK: - Question A: short form inside nested tag enum's View typealias
// ===----------------------------------------------------------------------===//
//
// Does unqualified `Property<Tag>` lookup from inside the nested `Insert`
// enum resolve to the enclosing type's `typealias Property<Tag>`?
// ===----------------------------------------------------------------------===//

struct Ring<Element: ~Copyable, let N: Int>: ~Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Self>

    enum Insert {
        // Q-A: does `Property<Insert>` resolve here?
        typealias View = Property<Insert>.View.Typed<Element>.Valued<N>
    }

    // Conclusion for Q-A is "does the typealias resolve?", which the line
    // above answers. Accessor-declaration shape is orthogonal and already
    // covered by swift-buffer-primitives and the per-symbol DocC examples.
}

// ===----------------------------------------------------------------------===//
// MARK: - Question B: extension on container-scoped typealias vs module type
// ===----------------------------------------------------------------------===//
//
// Deque is the test subject. Two verbs with distinct accessor names — `back`
// and `front` — demonstrate the two extension shapes against the SAME
// container without method-name collision and without compound identifiers.
//
// Shape A (canonical): `extension Property_Primitives.Property where ...`
//   Used for `.push.back(_:)`.
// Shape B (candidate): `extension Deque.Property where ...`
//   Used for `.push.front(_:)`.
// Both compile and coexist.
// ===----------------------------------------------------------------------===//

struct Deque<Element: Copyable>: Copyable {
    var _storage: [Element] = []

    enum Push {}
    enum Peek {}

    typealias Property<Tag> = Property_Primitives.Property<Tag, Deque<Element>>
}

extension Deque {
    var push: Property<Push> {
        _read { yield Property<Push>(self) }
        _modify {
            var property: Property<Push> = .init(self)
            self = Deque()
            defer { self = property.base }
            yield &property
        }
    }

    var peek: Property<Peek>.Typed<Element> {
        Property_Primitives.Property.Typed(self)
    }
}

// Shape A — extend module-level Property_Primitives.Property (canonical today).
// Adds `push.back(_:)` — appends to the end.
extension Property_Primitives.Property {
    mutating func back<E>(_ element: E)
    where Tag == Deque<E>.Push, Base == Deque<E> {
        base._storage.append(element)
    }
}

// Shape B — extend the container-scoped typealias Deque.Property.
// Adds `push.front(_:)` — inserts at the beginning.
// Method-level generic `E` introduces the element type; the where-clauses
// constrain the typealias's Tag and Base parameters.
extension Deque.Property {
    mutating func front<E>(_ element: E)
    where Tag == Deque<E>.Push, Base == Deque<E> {
        base._storage.insert(element, at: 0)
    }
}

// Shape B' — attempt extension on Deque.Property.Typed.
//
// REJECTED by the compiler:
//   error: 'Typed' is not a member type of type 'Deque.Property'
//
// Swift's generic typealias does not expose nested types of its underlying
// type for extension purposes. `Deque.Property<Peek>.Typed<E>` is valid at a
// USE site (that goes through the underlying Property and picks up Typed
// from there), but `extension Deque.Property.Typed` walks the typealias's
// declaration, not its expansion, and does not see Typed.
//
// Uncommenting the block below will fail to compile.
//
// extension Deque.Property.Typed
// where Tag == Deque<Element>.Peek, Base == Deque<Element> {
//     var last: Element? { base._storage.last }
// }

// Shape B'' — canonical property-case extension (module-level). Works.
// Adds `peek.back`, `peek.front`, `peek.count`.
extension Property_Primitives.Property.Typed
where Tag == Deque<Element>.Peek, Base == Deque<Element> {
    var back: Element? { base._storage.last }
    var front: Element? { base._storage.first }
    var count: Int { base._storage.count }
}

// ===----------------------------------------------------------------------===//
// MARK: - Runtime demo — Shapes A and B behave identically
// ===----------------------------------------------------------------------===//

var deque = Deque<Int>()
deque.push.back(1)     // Shape A
deque.push.back(2)
deque.push.front(0)    // Shape B

let back = deque.peek.back
let front = deque.peek.front
let count = deque.peek.count

print("Q-A  (short form in nested-enum typealias):     CONFIRMED")
print("Q-B  (extension on Deque.Property):             CONFIRMED")
print("Q-B' (extension on Deque.Property.Typed):       REJECTED by compiler")
print()
print("Runtime: storage=\(deque._storage)")
print("         peek.front=\(front ?? -1), peek.back=\(back ?? -1), peek.count=\(count)")
assert(deque._storage == [0, 1, 2])
assert(front == 0 && back == 2 && count == 3)

// ===----------------------------------------------------------------------===//
// MARK: - Findings and implications
// ===----------------------------------------------------------------------===//
//
// Q-A — short form in nested-enum typealias: WORKS.
//
//   The long-form `Property<Tag, Container<E, N>>` used inside nested tag
//   enums — shipped in skill [PRP-012] and in production consumers
//   (swift-queue-primitives, swift-hash-table-primitives) — is NOT a
//   compiler-requirement. It is a convention choice.
//
//   The convention choice is defensible: production consumers do NOT define
//   a container-level `typealias Property<Tag>` at all; they rely on the
//   tag-enum-View typealias being the ONLY shortcut the container has
//   adopted. Under that convention, long-form inside the tag-enum-View
//   typealias reads as "spell out the full underlying type once, hide it
//   behind the tag's typealias forever." Adding a second container-level
//   `Property<Tag>` shortcut is redundant at that point.
//
//   If a container DOES adopt the container-level `typealias Property<Tag>`
//   (as swift-property-primitives' Getting-Started tutorial does), then the
//   short form inside nested-enum typealiases works too — Q-A confirms it.
//
// Q-B — extension on Deque.Property: WORKS.
//
//   `extension Deque.Property where Tag == Deque<E>.Push, Base == Deque<E>`
//   compiles cleanly and is behaviorally identical to
//   `extension Property_Primitives.Property where ...`.
//
//   The where-clause still spells out `Tag == Deque<E>.Push, Base == Deque<E>`
//   with a method-level generic `E`, because the typealias signature is
//   `Property<Tag>` — it binds Tag only. Element does NOT become a
//   type-level parameter of Deque.Property. For the generic Deque<Element>
//   case, Shapes A and B are lexically comparable — neither saves lines
//   over the other.
//
//   Shape B becomes genuinely shorter only when the typealias is bound to
//   a non-generic Base (e.g., `typealias Prop<Tag> = Property<Tag, Int>` on
//   a hypothetical concrete Deque-of-Int), because then the `Base == ...`
//   side of the where-clause falls away.
//
// Q-B' — extension on Deque.Property.Typed: DOES NOT COMPILE.
//
//   Swift rejects `extension Deque.Property.Typed` because the generic
//   typealias `Deque.Property<Tag>` is not expanded during the extension's
//   member-type lookup. The compiler walks the typealias's declaration
//   signature (`Property<Tag>`) and does not find a nested `Typed` there.
//
//   Consequence: nested types of Property (Property.Typed, Property.View,
//   Property.Consuming, etc.) CANNOT be extended via the container-scoped
//   typealias. The canonical
//   `extension Property_Primitives.Property.Typed where Tag == ..., Base == ...`
//   is the ONLY shape that works for property-case extensions.
//
//   This asymmetry — Shape B works for Property itself, Shape B' does NOT
//   work for Property.Typed — is the reason the skill and DocC articles
//   canonicalise `extension Property_Primitives.Property.X where ...` for
//   all extension-site examples. A mixed regime (some extensions via
//   Deque.Property, others via Property_Primitives.Property) would be
//   actively confusing.
//
// ===----------------------------------------------------------------------===//
// RECOMMENDATION
// ===----------------------------------------------------------------------===//
//
//  1. At accessor-declaration sites inside the container: use the short
//     form `Property<Tag>` / `Property<Tag>.View` / `Property<Tag>.Typed<E>`
//     — [PRP-003] canonical, Getting-Started tutorial canonical.
//
//  2. At method-extension sites: keep the canonical
//     `extension Property_Primitives.Property.X where Tag == ..., Base == ...`
//     form. Shape B is permissible for Property itself but offers no real
//     savings; Shape B' (nested types through the typealias) is rejected,
//     so for consistency the module-qualified form wins.
//
//  3. Inside nested tag enums' own View typealiases (the tag-enum-View
//     pattern [PRP-012]): the long form is a convention, not a compiler
//     requirement. Production consumers (queue, hash-table) prefer long-form
//     for self-containment — no dependency on the container having adopted
//     `typealias Property<Tag>` at all.
// ===----------------------------------------------------------------------===//
