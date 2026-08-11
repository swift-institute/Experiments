// MARK: - Language-Semantic Property.Typed Replacement
//
// Purpose: Determine whether `Property<Tag, Base>.Typed<Element>` (the
// property-case variant carrying the `Element` generic for property
// extensions) can be replaced by pure Swift 6.3 language constructs.
//
// The motivation for `Property.Typed<Element>` is documented in
// `Research/property-type-family.md` §4.1: Swift methods can introduce
// generic parameters (`func back<E>(...) where Tag == Container<E>.Peek`)
// but computed properties cannot. `Typed<Element>` "smuggles" the element
// type into scope so property extensions can write `where Element == Int`.
//
// Hypothesis: A per-namespace proxy struct that declares its own
// `Element` generic parameter at the nesting level reproduces Property.Typed
// one-for-one; Property.Typed is not a language capability, it is an
// amortization.
//
// Toolchain: swift-6.3.1 (2026-04-17)
// Platform: macOS 26.0 (arm64)
//
// Status: V1 CONFIRMED (debug), V2 CONFIRMED (debug).
// Result: PARTIALLY-REPLACEABLE — identical to the Property case (exp #1).
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES
//   Pure-language works; Property.Typed's value is amortizing the
//   "owned-base + property-case + Element-in-scope" template across N
//   namespaces of any Copyable container.
// Date: 2026-04-21

// MARK: - V1: Pure-language — per-namespace proxy with its own Element generic
//
// Hypothesis: `container.peek.back` (returning `Int?`) compiles without
// Property.Typed if we declare a Peek proxy struct that carries
// `<Element>` at its own level and exposes `var back: Element?`.

public struct V1Container<Element>: Copyable {
    var storage: [Element]
    public init(_ elements: Element...) { self.storage = elements }
    public var count: Int { storage.count }
}

extension V1Container {
    public struct Peek: ~Copyable {
        var _base: V1Container<Element>
        public init(_ base: consuming V1Container<Element>) { self._base = base }
        public var base: V1Container<Element> {
            _read { yield _base }
            _modify { yield &_base }
        }
        // Element is in scope here via the outer V1Container<Element> nesting.
        // This is precisely Property.Typed's trick: nest the property-case
        // proxy inside the parametric outer scope so Element is available for
        // `var`-extensions, which cannot introduce their own generics.
        public var back: Element? { _base.storage.last }
        public var front: Element? { _base.storage.first }
    }

    public var peek: Peek {
        _read { yield Peek(self) }
        _modify {
            var proxy = Peek(self)
            self = V1Container<Element>()
            defer { self = proxy.base }
            yield &proxy
        }
    }
}

let v1 = V1Container<Int>(10, 20, 30)
print("V1 peek.back=\(v1.peek.back ?? -1) peek.front=\(v1.peek.front ?? -1)")
// Output: V1 peek.back=30 peek.front=10

// MARK: - V2: Pure-language — non-generic Peek for a fixed element type
//
// Hypothesis: When `Element` is concrete (Int), the proxy does not need
// a generic parameter at all. This is the degenerate case — the shipped
// `Property.Typed` machinery is overkill when Element is not phantom.

public struct V2Container: Copyable {
    var storage: [Int]
    public init(_ elements: Int...) { self.storage = elements }
}

extension V2Container {
    public struct Peek: ~Copyable {
        var _base: V2Container
        public init(_ base: consuming V2Container) { self._base = base }
        public var back: Int? { _base.storage.last }
    }

    public var peek: Peek {
        _read { yield Peek(self) }
    }
}

let v2 = V2Container(1, 2, 3)
print("V2 peek.back=\(v2.peek.back ?? -1)")  // Output: V2 peek.back=3

// MARK: - V3: Pure-language — stdlib keypath-on-property avoids Typed entirely
//
// Hypothesis: When the only goal is to expose a read-only property path
// `.peek.back`, a direct computed property on the container works.
// Property.Typed is only needed when the namespace (phantom Tag) must
// discriminate multiple property-case extensions on the same Base/Element.

public struct V3Container<Element>: Copyable {
    var storage: [Element]
    public init(_ elements: Element...) { self.storage = elements }

    public var backElement: Element? { storage.last }      // compound — [API-NAME-002] violation
    public var peekFront: Element? { storage.first }       // compound — [API-NAME-002] violation
}

let v3 = V3Container<Int>(100, 200, 300)
print("V3 backElement=\(v3.backElement ?? -1)")  // Output: V3 backElement=300

// MARK: - Results Summary
//
// V1: CONFIRMED (debug) — per-namespace proxy with its own Element generic
//     reproduces Property.Typed's `var back: Element?` capability.
// V2: CONFIRMED (debug) — when Element is concrete, no generic is needed.
// V3: Compiles, but VIOLATES [API-NAME-002] (compound identifier); rejected
//     on convention grounds. Same outcome as exp #1 V2.
//
// Verdict for Property.Typed<Element>: PARTIALLY-REPLACEABLE.
//   The Swift limitation that "properties cannot introduce generic
//   parameters" is NOT circumvented by Property.Typed — it is WORKED AROUND
//   by placing `Element` in the enclosing type's scope. V1 replicates that
//   workaround per-namespace: nest the `Peek` proxy inside `V1Container` so
//   `Element` reaches `var back` through ordinary lexical scoping.
//
// Property.Typed is the generic, tag-parameterised version of V1's `Peek`
// proxy. Pure language can write V1, but must write it fresh for every
// (container, namespace) pair that needs property-case extensions.
//
// The amortization ratio is the same as the plain Property case (exp #1):
// one definition in Core + one typealias per container vs. N per-namespace
// proxy definitions across the ecosystem. The consumer-ergonomics cost is
// also the same: the call site (`container.peek.back`) is identical in
// both shapes.
//
// Release-mode note: same Swift 6.3.1 SIL CrossModuleOptimization crash as
// exp #1 — see that experiment's header.
