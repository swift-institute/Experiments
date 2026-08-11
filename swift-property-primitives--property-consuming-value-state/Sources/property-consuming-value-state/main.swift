// MARK: - Property.Consuming value-type State redesign (Option C)
//
// Purpose: Validate that replacing `Property.Consuming.State` with a
//   `~Copyable` value-type struct eliminates the `@unchecked Sendable`
//   workaround entirely — at the cost of removing the shared-state
//   `init(state:)` capability.
//
// Hypothesis: A value-type `struct State: ~Copyable` whose stored
//   properties are `Base?` and `Bool` can:
//     1. Conform to `Sendable where Base: Sendable` WITHOUT `@unchecked`
//        — the compiler can verify all stored properties.
//     2. Support the borrow/consume/restore contract via Consuming's
//        `mutating` methods on a `var _state: State` field.
//     3. Support the canonical `_read`/`_modify` + `defer { restore() }`
//        accessor recipe (the production usage pattern).
//     4. Provide a borrowing `state` getter via `_read { yield _state }`.
//
// Non-goals (what Option C deliberately does NOT preserve):
//     - `init(state:)` sharing across multiple Consuming instances. With
//       a `~Copyable` value-type State, sharing a mutable state object
//       across separate Consuming instances is impossible by design.
//     - `state === state` reference-identity semantics — value types
//       don't have identity.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102), Xcode 26.4.1
// Platform: macOS 26.0 (arm64)
//
// Status: PARTIAL (as of Swift 6.3.1)
// Result: PARTIAL — design validated, but release-mode-blocked.
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES
//
//   Debug mode: CONFIRMED. Value-type `~Copyable` State supports the
//   full borrow/consume/restore contract and the canonical _read/_modify
//   accessor recipe. `extension State: Sendable where Base: Sendable {}`
//   compiles WITHOUT `@unchecked` — the compiler verifies `Base?` +
//   `Bool` directly. Runtime behavior matches production contract
//   (Outputs/run.txt).
//
//   Release mode: BLOCKED by Swift 6.3.1 SIL EarlyPerfInliner crash
//   ("Cannot initialize a nonCopyable type with a guaranteed value",
//   signal 6 / abort) when the canonical `_read` accessor yielding a
//   `~Copyable` value-type Consuming is inlined. Reproducer: build
//   this experiment itself with `swift build -c release` — crashes
//   at pass #23032 SILFunctionTransform "EarlyPerfInliner" inlining
//   Container.forEach's `_read`. Workaround: `@_optimize(none)` on
//   every accessor that yields a Consuming.
//
//   Performance comparison: see
//   Experiments/property-consuming-state-allocation-benchmark. Result
//   is within measurement noise — no meaningful perf win from Option C.
//   Escape analysis stack-promotes the class State in tight loops,
//   eliminating the theoretical heap-allocation cost that motivated
//   the redesign.
//
//   Verdict: production adoption REJECTED. The release-mode crash
//   requires `@_optimize(none)` at every CONSUMER accessor site
//   (not just in the library) in exchange for replacing `@unchecked
//   Sendable` with plain `Sendable`. Distributing a compiler
//   workaround to every adopter of the canonical Property.Consuming
//   pattern is hostile to consumer ergonomics, and there is no
//   runtime perf upside to offset that cost. swift-property-primitives
//   kept Option A (conditional `@unchecked Sendable` on class-based
//   State, commit a54cab8). Revisit when the EarlyPerfInliner crash
//   is fixed upstream.
//
//   Trade (additional, design-level): init(state:) and shared-state
//   semantics would go away by design. The state === state identity
//   check would be meaningless for value types.
//
// Date: 2026-04-21
// Date revised: 2026-04-21 (release-mode blocker added after performance
//   benchmark validated no perf upside)
//
// Provenance: swift-property-primitives Sendable survey on 2026-04-21.
//   The class-based State declared `@unchecked Sendable` to let the
//   outer `Property.Consuming: Sendable where Base: Sendable` propagate
//   through a reference-typed field. Option A narrowed the claim to
//   conditional (commit a54cab8); this experiment evaluates whether
//   Option C eliminates the `@unchecked` entirely.

// MARK: - Shared infrastructure (mirrors Property Primitives Core)

struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _base: Base

    @inlinable
    init(_ base: consuming Base) { self._base = base }
}

extension Property where Base: ~Copyable {
    @inlinable
    var base: Base {
        _read { yield _base }
        _modify { yield &_base }
    }
}

extension Property: Copyable where Base: Copyable {}
extension Property: Sendable where Base: Sendable {}

// MARK: - Option C: value-type ~Copyable State

extension Property where Base: Copyable {
    struct Consuming<Element>: ~Copyable {
        @usableFromInline
        internal var _state: State

        @inlinable
        init(_ base: consuming Base) {
            self._state = State(base)
        }
    }
}

extension Property.Consuming {
    /// Value-type state tracker.
    ///
    /// `~Copyable` prevents the sharing that required `init(state:)` in
    /// the class-based design. In return, the struct has no mutable
    /// reference semantics the compiler can't see — `Sendable` conforms
    /// without `@unchecked`.
    struct State: ~Copyable {
        @usableFromInline
        internal var _base: Base?

        @usableFromInline
        internal var _consumed: Bool

        @inlinable
        init(_ base: consuming Base) {
            self._base = base
            self._consumed = false
        }

        @inlinable
        var isConsumed: Bool { _consumed }

        @inlinable
        func borrow() -> Base? { _base }
    }
}

// NOTE the absence of `@unchecked` here — this compiles because the
// compiler can directly verify that `Base?` and `Bool` are Sendable
// when Base is Sendable.
extension Property.Consuming.State: Sendable where Base: Sendable {}

// MARK: - Projections (mirrors the production Consuming public API)

extension Property.Consuming {
    @inlinable
    var isConsumed: Bool { _state.isConsumed }

    @inlinable
    var state: State {
        _read { yield _state }
    }

    @inlinable
    func borrow() -> Base? { _state.borrow() }

    @inlinable
    mutating func consume() -> Base? {
        guard let base = _state._base else { return nil }
        _state._consumed = true
        _state._base = nil
        return base
    }

    @inlinable
    func restore() -> Base? {
        guard !_state._consumed else { return nil }
        return _state._base
    }
}

// MARK: - Conditional Sendable on the outer Consuming

extension Property.Consuming: Sendable where Base: Sendable {}

// MARK: - Verification

enum Phantom {}

// Basic borrow / consume / restore contract
func verifyBasicContract() {
    var c = Property<Phantom, Int>.Consuming<Int>(42)

    let initialBorrow = c.borrow()
    precondition(initialBorrow == 42, "borrow before consume returns base")
    precondition(c.isConsumed == false, "not consumed initially")

    let taken = c.consume()
    precondition(taken == 42, "consume returns base")
    precondition(c.isConsumed, "consumed after consume()")
    precondition(c.borrow() == nil, "borrow after consume returns nil")
    precondition(c.consume() == nil, "double consume returns nil")
    precondition(c.restore() == nil, "restore after consume returns nil")
}

// Canonical _read / _modify + defer + restore accessor recipe
struct Container: Copyable {
    var storage: [Int]
    enum ForEach {}

    var forEach: Property<ForEach, Container>.Consuming<Int> {
        _read {
            yield Property<ForEach, Container>.Consuming<Int>(self)
        }
        mutating _modify {
            var property = Property<ForEach, Container>.Consuming<Int>(self)
            self = Container(storage: [])
            defer {
                if let restored = property.restore() {
                    self = restored
                }
            }
            yield &property
        }
    }
}

extension Property.Consuming
where Tag == Container.ForEach, Base == Container, Element == Int {
    func callAsFunction(_ body: (Int) -> Void) {
        guard let base = borrow() else { return }
        for element in base.storage { body(element) }
    }

    mutating func consuming(_ body: (Int) -> Void) {
        guard let base = consume() else { return }
        for element in base.storage { body(element) }
    }
}

func verifyAccessorRecipe() {
    // Borrow path — container preserved
    let borrowContainer = Container(storage: [1, 2, 3])
    var borrowed: [Int] = []
    borrowContainer.forEach { borrowed.append($0) }
    precondition(borrowed == [1, 2, 3], "borrow path yields elements")
    precondition(borrowContainer.storage.count == 3, "borrow path preserves container")

    // Consume path — container emptied
    var consumeContainer = Container(storage: [10, 20, 30])
    var consumed: [Int] = []
    consumeContainer.forEach.consuming { consumed.append($0) }
    precondition(consumed == [10, 20, 30], "consume path yields elements")
    precondition(consumeContainer.storage.count == 0, "consume path empties container")
}

// Compile-time assertion: State is Sendable (conditional) WITHOUT @unchecked
private enum _RequireSendable<T: ~Copyable & Sendable> {}
private typealias _StateIsSendable = _RequireSendable<Property<Phantom, Int>.Consuming<Int>.State>
private typealias _ConsumingIsSendable = _RequireSendable<Property<Phantom, Int>.Consuming<Int>>

verifyBasicContract()
verifyAccessorRecipe()
print("Option C: value-type ~Copyable State validated.")
print("  - Sendable: YES, conditional on Base: Sendable")
print("  - @unchecked Sendable: NO — compiler verifies directly")
print("  - Shared state via init(state:): NO — deliberately removed")
print("  - Canonical accessor recipe: WORKS")
