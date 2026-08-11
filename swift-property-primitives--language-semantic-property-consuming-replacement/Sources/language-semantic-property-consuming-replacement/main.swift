// MARK: - Language-Semantic Property.Consuming Replacement
//
// Purpose: Evaluate the user's proposal that
//   `container.forEach.consuming { process($0) }`
// can be re-expressed with pure Swift 6.3 ownership vocabulary as
//   `container.forEach { process(consume $0) }`
// — and, more broadly, whether `Property.Consuming` (the runtime borrow-vs-
// consume state-machine) has a pure-language equivalent at the same call-site
// ergonomics.
//
// The production semantics of `Property.Consuming` is:
//   - ONE accessor declaration on the container (`var forEach: Property<ForEach,
//     Container<Element>>.Consuming<Element>`).
//   - Caller chooses at invocation: `container.forEach { … }` borrows and the
//     container stays populated; `container.forEach.consuming { … }` consumes
//     and the container is emptied on scope exit. The `_modify` accessor's
//     `defer` block consults `State._consumed` to decide whether to restore.
//
// Hypothesis: The proposed substitution is NOT semantically equivalent.
// `consume $0` in the closure body consumes the CLOSURE PARAMETER (one element
// at a time), not the CONTAINER. The container remains populated after the
// loop. The two-path runtime switch (borrow vs consume) requires either
// runtime state or two separate entry points at the language level.
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Platform: macOS 26.0 (arm64)
//
// Status:
//   V1 REFUTED — the user's worked-example substitution compiles but
//     produces different observable semantics.
//   V2 CONFIRMED — two distinct method names (`forEach` borrow, `drain`
//     consume) reproduce both observable behaviours without Property.Consuming
//     machinery, but surface-area doubles and [API-NAME-002] constrains the
//     names available (no `forEachConsuming`).
//   V3 CONFIRMED — nested type with `callAsFunction` (borrow) + `consuming`
//     method (consume) reproduces the `container.forEach.consuming { }`
//     call-site shape without the `Property.Consuming` generic machinery, at
//     the cost of per-namespace hand-rolling equivalent to the Property case.
// Result: PARTIALLY-REPLACEABLE (the call-site shape can be preserved; the
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//     state-machine is unavoidable at the mechanism layer).
// Date: 2026-04-21

// MARK: - V1: The user's proposal — `consume $0` inside the body
//
// Hypothesis under test: `container.forEach { process(consume $0) }` is
// equivalent to `container.forEach.consuming { process($0) }`.
//
// Observation: NOT equivalent. `consume $0` consumes the per-iteration
// parameter (a local binding); the container is unchanged after the loop.

public struct V1Container<Element: Copyable> {
    var storage: [Element]
    public init(_ elements: Element...) { self.storage = elements }
    public var count: Int { storage.count }

    public func forEach(_ body: (Element) -> Void) {
        for element in storage { body(element) }
    }
}

var v1 = V1Container<Int>(1, 2, 3)
var v1sum = 0
v1.forEach { v1sum += consume $0 }  // `consume $0` consumes the loop-local Int
// Compiler warning (evidence): "'consume' applied to bitwise-copyable type
// 'Int' has no effect" — the compiler itself flags this as a no-op for the
// common Copyable element case.
print("V1 after forEach(consume): count=\(v1.count) sum=\(v1sum)")
// Output: V1 after forEach(consume): count=3 sum=6
// Key observation: count is STILL 3. `consume $0` did nothing to the container.
// This is NOT what `container.forEach.consuming { }` does (which would empty
// the container to count=0).

// MARK: - V2: Two method names — `forEach` (borrow) + `drain` (consume self)
//
// Hypothesis: Expose two methods with distinct language-ownership conventions:
//   - `func forEach(_:)` (borrowing self) — container preserved.
//   - `consuming func drain(_:)` (consuming self) — container unconditionally
//     consumed; caller's binding becomes invalid.
// This matches both observable behaviours with pure language conventions.

public struct V2Container<Element: Copyable>: ~Copyable {
    var storage: [Element]
    public init(_ elements: Element...) { self.storage = elements }
    public var count: Int { storage.count }

    public func forEach(_ body: (Element) -> Void) {
        for element in storage { body(element) }
    }

    public consuming func drain(_ body: (Element) -> Void) {
        for element in storage { body(element) }
        // self is consumed; cannot be used after return.
    }
}

// ~Copyable globals cannot be consumed (Swift 6.3 rule); wrap in function scope.
func v2Demo() {
    // Borrow path
    let v2 = V2Container<Int>(10, 20, 30)
    v2.forEach { print("V2 borrow: \($0)") }
    // Output: V2 borrow: 10 / 20 / 30
    // v2 is still usable here.

    // Consume path — caller binding ends after drain()
    let v2b = V2Container<Int>(100, 200, 300)
    v2b.drain { print("V2 drain: \($0)") }
    // v2b cannot be referenced again — it was consumed by drain.
}
v2Demo()

// MARK: - V3: Nested type — callAsFunction + consuming method
//
// Hypothesis: Reproduce `container.forEach { }` (borrow) and
// `container.forEach.consuming { }` (consume) using a per-namespace hand-rolled
// type with `callAsFunction` (borrow path) + a `mutating` (or consuming)
// method (consume path) + a state object driving the container's `_modify`
// `defer` to decide whether to restore.
//
// This mirrors exactly what `Property.Consuming` does internally — the state
// class is ~15 lines per container instead of amortised into the shipped
// `Property.Consuming` type.

public final class V3State<Element: Copyable> {
    var _storage: [Element]?
    var _consumed: Bool = false
    init(_ storage: [Element]) { self._storage = storage }
}

public struct V3ForEach<Element: Copyable>: ~Copyable {
    let _state: V3State<Element>

    init(_ state: V3State<Element>) { self._state = state }

    public func callAsFunction(_ body: (Element) -> Void) {
        guard let storage = _state._storage else { return }
        for element in storage { body(element) }
    }

    public mutating func consuming(_ body: (Element) -> Void) {
        guard let storage = _state._storage else { return }
        _state._consumed = true
        _state._storage = nil
        for element in storage { body(element) }
    }
}

public struct V3Container<Element: Copyable> {
    var storage: [Element]
    public init(_ elements: Element...) { self.storage = elements }
    public var count: Int { storage.count }

    public var forEach: V3ForEach<Element> {
        _read { yield V3ForEach(V3State(storage)) }
        _modify {
            let state = V3State(storage)
            storage = []
            var property = V3ForEach<Element>(state)
            defer {
                if !state._consumed, let restored = state._storage {
                    self.storage = restored
                }
            }
            yield &property
        }
    }
}

// Borrow path — container preserved
var v3 = V3Container<Int>(1, 2, 3)
var v3sum = 0
v3.forEach { v3sum += $0 }
print("V3 borrow: count=\(v3.count) sum=\(v3sum)")
// Output: V3 borrow: count=3 sum=6

// Consume path — container emptied
var v3b = V3Container<Int>(10, 20, 30)
var v3bsum = 0
v3b.forEach.consuming { v3bsum += $0 }
print("V3 consume: count=\(v3b.count) sum=\(v3bsum)")
// Output: V3 consume: count=0 sum=60

// MARK: - Results Summary
//
// V1 (user's worked example): REFUTED. `consume $0` inside the body targets
//     the per-iteration local, not the container. The container is unchanged
//     after the loop. The proposed substitution reads similarly but means
//     something different; it is not a replacement.
//
// V2 (two method names): CONFIRMED semantically. `consuming func drain(_:)`
//     reproduces the "consume on demand" behaviour using pure language ownership.
//     Cost: consumes the entire container binding — the caller's variable is
//     invalid after the call, which is STRONGER than Property.Consuming's
//     "empty the container but keep the binding". For call sites that need to
//     keep an empty container alive (e.g., to refill and reuse), V2 is wrong.
//     Naming: the second method cannot be `forEach.consuming` as a nested
//     path without a proxy type; it must be a top-level method, and
//     [API-NAME-002] forbids `forEachConsuming`. Options are `drain` (used
//     here), `consume`, or a differently-shaped API.
//
// V3 (nested type + state): CONFIRMED. Full behavioural parity with
//     Property.Consuming — the state class, the `_modify`+defer+restore
//     recipe, and the `callAsFunction`/`consuming` method split. But this is
//     exactly the mechanism `Property.Consuming` factors out; replacing
//     `Property.Consuming` with hand-rolled V3 requires rewriting the state
//     class and the accessor recipe per container namespace.
//
// Verdict for Property.Consuming: PARTIALLY-REPLACEABLE.
//   The call-site shape (`container.forEach { }` vs `container.forEach.consuming { }`)
//   is reproducible with pure language, but ONLY by hand-rolling the same
//   state-machine that Property.Consuming encapsulates. The user's proposed
//   `consume $0` substitution is a different operation and does not replace
//   the type.
//
//   The ownership-transfer vocabulary (`consume`, `consuming self`, `borrow`)
//   does not express "at runtime, decide whether to consume the whole
//   container" — that is a runtime state-machine question, not an ownership
//   annotation question. Language annotations are static; Property.Consuming
//   is dynamic.
//
//   If the ecosystem is willing to accept V2's semantics (consume the whole
//   binding with `drain`), Property.Consuming is REPLACEABLE for those call
//   sites. If the preserved-but-empty binding semantics of .forEach.consuming
//   are load-bearing for consumers, Property.Consuming stays.
