// MARK: - Property.View over Ownership.Inout: factoring verification
//
// Purpose: Determine whether Property.View<Tag, Base>'s extension patterns
//          survive a refactor where its internal storage becomes
//          `Ownership.Inout<Base>` instead of `UnsafeMutablePointer<Base>`,
//          and whether the cleaner framing `Tagged<Tag, Ownership.Inout<Base>>`
//          (using swift-tagged-primitives' Tagged) produces a type that is
//          instantiable, extendable, and yieldable from `mutating _read` /
//          `mutating _modify` accessors.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26.0 (arm64)
// Date: 2026-04-23
//
// Status: COMPLETE
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// Result summary:
//   V1 / V2 / V3 — REFUTED. Tagged's current declaration
//     (`public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable>: ~Copyable`)
//     implicitly constrains `RawValue: Escapable`, and `Ownership.Inout` is
//     `~Escapable`. Diagnostic: "no type for 'RawValue' can satisfy both
//     'RawValue == Ownership.Inout<Inventory>' and 'RawValue : Escapable'".
//     Tagged-as-written cannot wrap an ~Escapable RawValue.
//
//   V4 — CONFIRMED. A bespoke `MyView<Tag, Base>: ~Copyable, ~Escapable` that
//     internally stores `Ownership.Inout<Base>` compiles, supports Tag+Base-
//     constrained extensions that mutate through `_ref.value`, and integrates
//     with the existing `mutating _read`/`_modify` accessor pattern on a
//     ~Copyable container. Runtime output: `[100, 200, 300]`. This is the
//     internal-refactor option: Property.View's public API stays unchanged,
//     its internal storage consolidates onto `Ownership.Inout`.
//
//   V5 — CONFIRMED. An in-experiment `ExTagged` with the signature
//     `public struct ExTagged<Tag: ~Copyable, RawValue: ~Copyable & ~Escapable>:
//                                                          ~Copyable, ~Escapable`
//     wraps `Ownership.Inout<Inventory>`, supports the Tag+RawValue-
//     constrained extension pattern, and the accessor pattern works. Runtime
//     output: `[1000, 2000, 3000]`. Demonstrates that generalizing the real
//     `Tagged` (admit ~Escapable RawValue, suppress Escapable on the struct
//     itself) makes the `Tagged<Tag, Ownership.Inout<Base>>` factoring viable.
//
//   V6 — CONFIRMED. Conditional Escapable re-addition works. With the
//     orthogonal conditional conformances
//       `extension ExTaggedV6: Copyable where Tag: ~Copyable,
//                                             RawValue: Copyable & ~Escapable {}`
//       `extension ExTaggedV6: Escapable where Tag: ~Copyable,
//                                              RawValue: Escapable & ~Copyable {}`
//     existing consumers `Tagged<_, Escapable T>` remain Escapable, while
//     new consumers `Tagged<_, ~Escapable T>` (e.g., `Ownership.Inout<Base>`)
//     are correctly ~Escapable. Runtime proof: an
//     `ExTaggedV6<OrdinalTag, Int>` is accepted by `func acceptsEscapable<T>(_)`
//     (requires `T: Escapable`), while an
//     `ExTaggedV6<Push, Ownership.Inout<Inventory>>` is lifetime-bounded.
//     Swift 6.3 requires both conformances to explicitly state the
//     orthogonal axis (Copyable conformance must say `RawValue: ~Escapable`
//     to admit both Escapable and ~Escapable RawValues; Escapable
//     conformance must say `RawValue: ~Copyable` to admit both).
//
// Implications:
//   - Path B (generalize the real Tagged) is **non-breaking** for existing
//     consumers of `Tagged<Tag, EscapableRawValue>`. The generalization
//     requires three changes in `swift-tagged-primitives/Sources/
//     Identity Primitives/Tagged.swift`:
//       1. Declaration: `Tagged<Tag: ~Copyable, RawValue: ~Copyable & ~Escapable>:
//                                                           ~Copyable, ~Escapable`
//       2. Update existing `Tagged: Copyable where RawValue: Copyable` to
//          `Tagged: Copyable where Tag: ~Copyable, RawValue: Copyable & ~Escapable`
//       3. Add `Tagged: Escapable where Tag: ~Copyable, RawValue: Escapable & ~Copyable`
//     Every existing Tagged consumer continues to work; new ~Escapable
//     RawValue uses become available.
//   - Path A (internal refactor of Property.View without touching Tagged)
//     remains viable as a fallback. It creates intermediate debt (two
//     migrations to reach the V5/V6 endpoint) but is a legitimate defer
//     option if Path B surfaces consumer-audit blockers.
//   - Recommended order: **Path B first.** The V6 evidence shows the
//     Tagged generalization is non-breaking. After B lands, Property.View
//     can be re-expressed as `Tagged<Tag, Ownership.Inout<Base>>` (or a
//     typealias), and `Property.View.Read` similarly as
//     `Tagged<Tag, Ownership.Borrow<Base>>` — resolving the layering
//     concern the user raised in one step rather than two.

public import Ownership_Primitives

// ============================================================================
// MARK: - Shared test base: a trivial ~Copyable container
// ============================================================================

struct Inventory: ~Copyable {
    var items: [Int] = []

    mutating func add(_ n: Int) {
        items.append(n)
    }

    mutating func removeLast() -> Int? {
        items.isEmpty ? nil : items.removeLast()
    }
}

enum Push {}

// ============================================================================
// MARK: - V4: Internal-refactor option — custom ~Copyable struct wrapping
//             Ownership.Inout<Base>. This preserves Property.View's existing
//             public API shape while consolidating storage onto the
//             ownership-primitives primitive.
// ============================================================================
// Hypothesis V4: A `MyView<Tag, Base>` struct that stores `Ownership.Inout<Base>`
//                internally compiles, can be extended with Tag+Base-constrained
//                methods that mutate through `_ref.value`, and can be yielded
//                from a `mutating _read`/`mutating _modify` accessor using the
//                same call-site shape as today's Property.View.
//
//                This is Option A from the architectural discussion: a pure
//                internal consolidation with no public API change for callers.
// ============================================================================

@safe
public struct MyView<Tag: ~Copyable, Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline internal var _ref: Ownership.Inout<Base>

    @inlinable
    @_lifetime(&base)
    public init(_ base: inout Base) {
        self._ref = Ownership.Inout(mutating: &base)
    }
}

// Tag+Base-constrained extension: adds a domain method by mutating through
// _ref.value. This is the direct analog of today's pattern:
//
//   extension Property.View where Tag == Push, Base == Inventory, Element: ~Copyable {
//       mutating func item(_ n: Int) { unsafe base.pointee.add(n) }
//   }
//
extension MyView where Tag == Push, Base == Inventory {
    mutating func item(_ n: Int) {
        _ref.value.add(n)
    }
}

// Accessor on the container that yields MyView from _read/_modify. Direct
// analog of today's:
//
//   var push: Property<Push, Self>.View {
//       mutating _read { yield unsafe Property<Push, Self>.View(&self) }
//       mutating _modify { var view = unsafe Property<Push, Self>.View(&self); yield &view }
//   }
//
extension Inventory {
    var push: MyView<Push, Inventory> {
        mutating _read {
            yield MyView(&self)
        }
        mutating _modify {
            var view = MyView<Push, Inventory>(&self)
            yield &view
        }
    }
}

func v4_internalRefactor() {
    var inventory = Inventory()

    // Call site is identical in shape to today's Property.View pattern.
    inventory.push.item(100)
    inventory.push.item(200)
    inventory.push.item(300)

    print("V4 inventory after accessor use:", inventory.items)
}

// ============================================================================
// MARK: - V5: Modified Tagged admitting ~Escapable RawValue
// ============================================================================
// Hypothesis V5: If Tagged were declared
//
//     public struct Tagged<Tag: ~Copyable, RawValue: ~Copyable & ~Escapable>:
//                                                          ~Copyable, ~Escapable
//
//   (i.e., admit ~Escapable RawValue and become ~Escapable itself), the
//   `Tagged<Tag, Ownership.Inout<Base>>` factoring from V1–V3 becomes viable.
//   The existing `Tagged: Copyable where RawValue: Copyable` conditional
//   conformance still narrows the type to Copyable in the common case.
//
//   This variant tests the shape in-experiment via a local `ExTagged` type —
//   it does not yet modify the real `Tagged_Primitives.Tagged`. If V5
//   passes, the path for the real change is a surgical edit to Tagged.swift
//   (loosen RawValue constraint + add `~Escapable` suppression).
// ============================================================================

@frozen
public struct ExTagged<Tag: ~Copyable, RawValue: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var rawValue: RawValue

    @inlinable
    @_lifetime(copy rawValue)
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

// Tag+RawValue-constrained extension: mutate through rawValue.value on the
// wrapped Ownership.Inout — the exact shape V1/V2 tried to use.
extension ExTagged where Tag == Push, RawValue == Ownership.Inout<Inventory> {
    mutating func item(_ n: Int) {
        rawValue.value.add(n)
    }
}

// Accessor pattern — the load-bearing piece. Yields ExTagged from _read/_modify.
extension Inventory {
    var pushV5: ExTagged<Push, Ownership.Inout<Inventory>> {
        mutating _read {
            let ref = Ownership.Inout(mutating: &self)
            yield ExTagged(__unchecked: (), ref)
        }
        mutating _modify {
            let ref = Ownership.Inout(mutating: &self)
            var tagged = ExTagged<Push, Ownership.Inout<Inventory>>(__unchecked: (), ref)
            yield &tagged
        }
    }
}

func v5_modifiedTagged() {
    var inventory = Inventory()

    inventory.pushV5.item(1000)
    inventory.pushV5.item(2000)
    inventory.pushV5.item(3000)

    print("V5 inventory after accessor use:", inventory.items)
}

// ============================================================================
// MARK: - V6: Conditional Escapable re-addition
// ============================================================================
// Hypothesis V6: A Tagged variant declared ~Escapable can conditionally become
//                Escapable via an extension constrained on `RawValue: Escapable`.
//                If this works, generalizing the real Tagged (Path B) is
//                non-breaking for every existing Tagged<Tag, EscapableValue>
//                consumer — they stay Escapable, while the new construction
//                `Tagged<Tag, Ownership.Inout<Base>>` is ~Escapable.
// ============================================================================

@frozen
public struct ExTaggedV6<Tag: ~Copyable, RawValue: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    public var rawValue: RawValue

    @inlinable
    @_lifetime(copy rawValue)
    public init(__unchecked: Void, _ rawValue: consuming RawValue) {
        self.rawValue = rawValue
    }
}

// Conditional conformances mirror the existing Tagged pattern, with each
// axis explicitly stating its orthogonal constraint (per Swift 6.3 rule
// "conditional conformance to X must explicitly state whether RawValue is
// required to conform to Y or not").
extension ExTaggedV6: Copyable where Tag: ~Copyable, RawValue: Copyable & ~Escapable {}

// The load-bearing line: narrow the ~Escapable default back to Escapable
// whenever RawValue is Escapable. If this extension compiles, existing
// Tagged<Tag, Escapable T> consumers remain Escapable after the Path B
// generalization.
extension ExTaggedV6: Escapable where Tag: ~Copyable, RawValue: Escapable & ~Copyable {}

// Smoke test: an Escapable RawValue (Int) gives an Escapable ExTaggedV6, so it
// CAN be stored in an Escapable container. A ~Escapable RawValue
// (Ownership.Inout<Inventory>) gives a ~Escapable ExTaggedV6 that the
// compiler correctly forbids from escaping.

enum OrdinalTag {}

func v6_conditionalEscapable() {
    // Path 1: Escapable RawValue → Escapable Tagged. Must be storable as an
    // ordinary let binding that can appear anywhere an Escapable value can.
    let escapableTagged = ExTaggedV6<OrdinalTag, Int>(__unchecked: (), 42)

    // If the conditional `extension : Escapable where RawValue: Escapable`
    // worked, the following function — which requires an Escapable argument —
    // will accept `escapableTagged` without complaint.
    acceptsEscapable(escapableTagged)

    // Path 2: ~Escapable RawValue → ~Escapable Tagged (lifetime-bounded by the
    // original storage). Must compile but cannot escape its scope.
    var inventory = Inventory()
    let inoutRef = Ownership.Inout(mutating: &inventory)
    var nonEscapableTagged = ExTaggedV6<Push, Ownership.Inout<Inventory>>(
        __unchecked: (), inoutRef
    )
    nonEscapableTagged.rawValue.value.add(10_000)
    _ = consume nonEscapableTagged

    print("V6 escapable.rawValue:", escapableTagged.rawValue,
          "non-escapable wrote:", inventory.items)
}

// Requires Escapable — proves V6's conditional Escapable works for the
// Escapable RawValue case.
func acceptsEscapable<T>(_ value: T) {
    _ = value
}

// ============================================================================
// MARK: - Run
// ============================================================================

v4_internalRefactor()
v5_modifiedTagged()
v6_conditionalEscapable()
