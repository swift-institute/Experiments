// MARK: - Language-Semantic Property Replacement
//
// Purpose: Determine whether the `Property<Tag, Base>` wrapper (owned method-case)
// can be replaced by pure Swift 6.3 language constructs at equivalent ergonomics
// for the canonical `container.push.back(_:)` / `container.pop.back()` /
// `container.merge.from(_:)` namespace-method accessor pattern on a
// `Copyable` container.
//
// Hypothesis: Pure language can reproduce the CALL SITE (`container.push.back(42)`)
// but requires per-namespace hand-rolling of the CoW-safe `_modify` transfer-and-defer
// recipe, losing the factoring that `Property<Tag, Base>` amortizes across namespaces.
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Platform: macOS 26.0 (arm64)
//
// Status: V1 CONFIRMED (debug), V2 CONFIRMED (debug). Pure-language
// replacement COMPILES at call-site equivalence in debug, but shifts cost:
// every namespace ships its own proxy struct with a duplicated `_modify`
// recipe. `Property<Tag, Base>` earns its keep as a proxy-struct factory,
// not as a compile-time capability.
// Result: PARTIALLY-REPLACEABLE (compiles; amortization lost).
// Release-mode note: `swift build -c release` hits a Swift 6.3.1 SIL
// CrossModuleOptimization crash ("Cannot initialize a nonCopyable type with
// a guaranteed value" in `forwardToInit`) — this is the same inliner-interaction
// issue tracked by the Experiments/property-consuming-value-state entry. The
// shipped Property type sidesteps it by living in a separate library target;
// single-module executable + ~Copyable proxy + `_read`/`_modify` coroutine
// hits the bug. Orthogonal to the semantic-equivalence question.
// Date: 2026-04-21

// MARK: - V1: Pure language — per-namespace hand-rolled proxy (no phantom generic)
//
// Hypothesis: Reproduce `container.push.back(42)` by declaring one concrete proxy
// struct per namespace, each carrying the CoW `_modify` recipe directly.
//
// Result: CONFIRMED — builds clean. Cost: every namespace is ~20 lines of
// boilerplate that `Property<Tag, Base>` would otherwise amortize to zero.

public struct V1Container: Copyable {
    var storage: [Int]
    public init(_ elements: Int...) { self.storage = elements }
    public var count: Int { storage.count }
}

extension V1Container {
    public struct PushProxy: ~Copyable {
        var _base: V1Container
        public init(_ base: consuming V1Container) { self._base = base }
        public var base: V1Container {
            _read { yield _base }
            _modify { yield &_base }
        }
        public mutating func back(_ element: Int) {
            _base.storage.append(element)
        }
    }

    public struct PopProxy: ~Copyable {
        var _base: V1Container
        public init(_ base: consuming V1Container) { self._base = base }
        public var base: V1Container {
            _read { yield _base }
            _modify { yield &_base }
        }
        public mutating func back() -> Int {
            _base.storage.removeLast()
        }
    }

    public var push: PushProxy {
        _read { yield PushProxy(self) }
        _modify {
            var proxy = PushProxy(self)
            self = V1Container()
            defer { self = proxy.base }
            yield &proxy
        }
    }

    public var pop: PopProxy {
        _read { yield PopProxy(self) }
        _modify {
            var proxy = PopProxy(self)
            self = V1Container()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

// Call-site check — identical shape to the production canonical pattern:
var v1 = V1Container(1, 2, 3)
v1.push.back(4)
v1.push.back(5)
let v1popped = v1.pop.back()
print("V1 count=\(v1.count) popped=\(v1popped)")  // Output: V1 count=4 popped=5

// MARK: - V2: Pure language — no proxy, direct consuming/mutating methods on the container
//
// Hypothesis: Drop the proxy entirely and expose `pushBack(_:)` / `popBack()`
// directly on the container.
//
// Result: CONFIRMED compiles, but VIOLATES [API-NAME-002] (no compound
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES
// identifiers). Rejected on convention grounds, not semantics.
// The convention rule (`container.push.back(_:)`) forces the namespace;
// the namespace forces a proxy type (V1 or `Property<Tag, Base>`).

public struct V2Container: Copyable {
    internal var storage: [Int]
    public init(_ elements: Int...) { self.storage = elements }
    public var count: Int { storage.count }
    public mutating func pushBack(_ element: Int) { storage.append(element) }  // compound — [API-NAME-002] violation
    public mutating func popBack() -> Int { storage.removeLast() }             // compound — [API-NAME-002] violation
}

var v2 = V2Container(1, 2, 3)
v2.pushBack(4)
let v2popped = v2.popBack()
print("V2 count=\(v2.count) popped=\(v2popped)")  // Output: V2 count=3 popped=4

// MARK: - Results Summary
//
// V1: CONFIRMED — pure-language replacement works at call-site equivalence.
//     Cost: per-namespace proxy struct + CoW _modify recipe duplication.
//     Semantic equivalence: full.
//
// V2: CONFIRMED compiles but VIOLATES [API-NAME-002] compound-identifier ban.
//     The nested-accessor convention (`container.push.back`) requires a proxy
//     type to host `.back`; pure flat methods cannot satisfy the naming rule.
//
// Verdict for Property<Tag, Base>: PARTIALLY-REPLACEABLE.
//   - The TYPE is not load-bearing on language capability — V1 shows direct
//     per-namespace proxies compile and behave identically.
//   - The TYPE IS load-bearing on amortization — `Property<Tag, Base>` is a
//     single generic proxy that factors the CoW _modify recipe (~8 lines ×
//     N namespaces) into one declaration, with phantom-tag extension
//     constraints selecting the method set. Pure-language replacement forces
//     the ~8 lines to be written N times.
//   - The abstraction's cost is one type definition in the Property Primitives
//     Core target + one typealias per container. The abstraction's benefit is
//     zero duplication across namespaces. Removing Property<Tag, Base> trades
//     abstraction for duplication.
