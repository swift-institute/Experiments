// MARK: - Cache Effect Type Nesting
// Purpose: Determine whether Swift allows nesting effect types inside a
//   generic struct when the protocol's associated type name conflicts with
//   an outer generic parameter name.
// Hypothesis: Multiple workarounds may enable nesting; at least one of
//   _Value capture, split declaration/conformance, or explicit typealias
//   should work.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — `typealias _Value = Value` on the outer type enables
//   nesting for both Evict (A1) and Compute (B2). Split declaration/conformance
//   (A2, A4) REFUTED: typealias retroactively reinterprets stored property types.
//   Explicit `typealias Value = Value` (B1) REFUTED: circular reference.
//   Direct inference from outer scope (B0) REFUTED: compiler cannot infer.
// Date: 2026-03-20

// MARK: - Minimal Protocol (mirrors Effect.Protocol)

protocol EffectProtocol: Sendable {
    associatedtype Arguments: Sendable = Void
    associatedtype Value: Sendable
    associatedtype Failure: Error = Never
    var arguments: Arguments { get }
}

extension EffectProtocol where Arguments == Void {
    var arguments: Void { () }
}

// MARK: - Minimal Generic Container (mirrors Cache<Key, Value>)

struct Container<Key: Hashable & Sendable, Value: Sendable>: Sendable {}

// =============================================================================
// MARK: - Problem A: Evict (typealias Value = Void shadows outer Value)
// =============================================================================
//
// __CacheEvict needs:
//   - Effect.Protocol.Value = Void (eviction returns nothing)
//   - A stored property `let value: Value` where Value is the CACHE's Value
//
// Nesting Evict inside Cache causes `typealias Value = Void` to shadow
// the outer generic parameter, making `let value: Value` resolve to Void.

// MARK: - Variant A0: Baseline — Direct nesting (expected: FAIL)
// Hypothesis: typealias Value = Void shadows the outer generic parameter
// Result: REFUTED — `let value: Value` resolves to Void, not Container.Value

#if false // VARIANT_A0 — does not compile
extension Container {
    struct Evict: EffectProtocol, Sendable {
        typealias Value = Void
        typealias Failure = Never

        let key: Key
        let value: Value   // ← resolves to Void, not Container.Value
        let reason: String

        var arguments: (key: Key, value: Value, reason: String) {
            (key, value, reason)
        }
    }
}
#endif

// MARK: - Variant A1: _Value capture typealias
// Hypothesis: Declaring `typealias _Value = Value` on Container before
//   the nested type lets the nested type reference `_Value` to access
//   the outer generic parameter even after shadowing `Value`.
// Result: CONFIRMED — Build Succeeded, runtime: key=k value=42 reason=test, Value=Void

extension Container {
    typealias _Value = Value
}

#if VARIANT_A1
extension Container {
    struct Evict_A1: EffectProtocol, Sendable {
        typealias Value = Void
        typealias Failure = Never

        let key: Key
        let value: _Value
        let reason: String

        var arguments: (key: Key, value: _Value, reason: String) {
            (key, value, reason)
        }
    }
}
#endif

// MARK: - Variant A2: Split declaration and conformance
// Hypothesis: Declare the struct without the protocol (so `Value` still
//   refers to outer generic), then add conformance with `typealias Value = Void`
//   in a separate extension. Stored property types are fixed at declaration.
// Result: REFUTED — typealias Value = Void retroactively reinterprets all
//   occurrences of Value in the type, including stored properties.
//   error: cannot convert value of type 'Int' to expected argument type 'Void'
//   Command: swift build -Xswiftc -DVARIANT_A2

#if VARIANT_A2
extension Container {
    struct Evict_A2: Sendable {
        let key: Key
        let value: Value   // Value = outer generic parameter
        let reason: String
    }
}

extension Container.Evict_A2: EffectProtocol {
    typealias Value = Void   // satisfies associated type
    typealias Failure = Never

    var arguments: (key: Key, value: Container._Value, reason: String) {
        (key, value, reason)
    }
}
#endif

// MARK: - Variant A3: Explicit CachedValue generic parameter
// Hypothesis: Give the nested type its own generic parameter with a different
//   name for the cached value. Works but requires redundant type parameter.
// Result: CONFIRMED — Build Succeeded, runtime correct. But ergonomically poor:
//   Container<String, Int>.Evict_A3<Int> requires redundant type parameter.
//   Swift infers CachedValue from init args, but explicit type refs are verbose.

#if VARIANT_A3
extension Container {
    struct Evict_A3<CachedValue: Sendable>: EffectProtocol, Sendable {
        typealias Value = Void
        typealias Failure = Never

        let key: Key
        let value: CachedValue
        let reason: String

        var arguments: (key: Key, value: CachedValue, reason: String) {
            (key, value, reason)
        }
    }
}

// Usage would require: Container<String, Int>.Evict_A3<Int> — redundant
func testA3() {
    let e = Container<String, Int>.Evict_A3(key: "k", value: 42, reason: "test")
    let _: Void.Type = type(of: e).Value.self  // EffectProtocol.Value = Void
    print("A3: key=\(e.key) value=\(e.value) reason=\(e.reason)")
}
#endif

// MARK: - Variant A4: where clause on extension to bind _Value
// Hypothesis: Use `where _Value == Value` constraint or similar to
//   re-export the outer Value under a non-shadowed name within the
//   conformance extension.
// Result: REFUTED — Same failure as A2. typealias Value = Void retroactively
//   reinterprets stored property types even when conformance is in a separate
//   extension from the struct declaration.
//   error: cannot convert value of type 'Int' to expected argument type 'Void'
//   Command: swift build -Xswiftc -DVARIANT_A4

#if VARIANT_A4
extension Container {
    struct Evict_A4: Sendable {
        let key: Key
        let value: Value
        let reason: String
    }
}

// Try conformance in constrained extension
extension Container.Evict_A4: EffectProtocol {
    // The protocol's Value should be Void, but we still have `value: Value`
    // where Value = outer generic. Does this create a conflict?
    typealias Value = Void
    typealias Failure = Never

    var arguments: Void { () }
}
#endif

// MARK: - Variant A5: Conditional conformance via where clause
// Hypothesis: Declare struct without protocol, add conformance with
//   `where Value == Void`. Avoids typealias entirely.
// Result: REFUTED — Creates a conditional conformance: Evict_A5 only conforms
//   to EffectProtocol when Cache.Value == Void. Container<String, Int>.Evict_A5
//   does NOT conform.
//   error: requires the types 'Int' and '()' be equivalent
//   Command: swift build -Xswiftc -DVARIANT_A5

#if VARIANT_A5
extension Container {
    struct Evict_A5: Sendable {
        let key: Key
        let value: Value
        let reason: String
    }
}

extension Container.Evict_A5: EffectProtocol where Value == Void {
    typealias Failure = Never
    var arguments: Void { () }
}

func testA5() {
    // This should work for Container<String, Void>.Evict_A5
    let e1 = Container<String, Void>.Evict_A5(key: "k", value: (), reason: "test")
    print("A5 (Void): key=\(e1.key) reason=\(e1.reason)")

    // But does Container<String, Int>.Evict_A5 conform to EffectProtocol?
    let e2 = Container<String, Int>.Evict_A5(key: "k", value: 42, reason: "test")
    func requiresEffect<T: EffectProtocol>(_ t: T) { print("A5: conforms") }
    requiresEffect(e2)  // ← expected: compile error
}
#endif

// =============================================================================
// MARK: - Problem B: Compute (outer Value for associated type in nested generic)
// =============================================================================
//
// __CacheCompute<Key, Value, E> needs:
//   - Effect.Protocol.Value = the CACHE's Value (the computed result)
//   - Its own generic parameter E for the error type
//
// Nesting Compute<E> inside Cache<Key, Value> should let it use the outer
// Value for the associated type. But the compiler reportedly cannot infer
// the associated type from the enclosing generic context.

// MARK: - Variant B0: Baseline — Direct nesting (expected: may work?)
// Hypothesis: Since Compute doesn't shadow Value, it should be able to
//   satisfy Effect.Protocol.Value from the outer generic parameter directly.
// Result: REFUTED — Compiler cannot infer associatedtype Value from outer
//   generic context when the nested type introduces its own generic parameter.
//   error: type 'Container<Key, Value>.Compute_B0<E>' does not conform to protocol 'EffectProtocol'
//   Command: swift build -Xswiftc -DVARIANT_B0

#if VARIANT_B0
extension Container {
    struct Compute_B0<E: Error & Sendable>: EffectProtocol {
        typealias Failure = E
        // Effect.Protocol.Value should be inferred from Container.Value

        let key: Key
        var arguments: Key { key }
    }
}

func testB0() {
    let c = Container<String, Int>.Compute_B0<any Error>(key: "test")
    print("B0: key=\(c.key)")
    let _: Int.Type = type(of: c).Value.self  // Should be Int
}
#endif

// MARK: - Variant B1: Explicit typealias Value = Value
// Hypothesis: Providing an explicit `typealias Value = Value` makes the
//   compiler associate the outer generic parameter with the protocol requirement.
// Result: REFUTED — Compiler treats `typealias Value = Value` as self-referencing.
//   error: type alias 'Value' references itself
//   Command: swift build -Xswiftc -DVARIANT_B1

#if VARIANT_B1
extension Container {
    struct Compute_B1<E: Error & Sendable>: EffectProtocol {
        typealias Value = Value  // explicitly bind to outer Value
        typealias Failure = E

        let key: Key
        var arguments: Key { key }
    }
}

func testB1() {
    let c = Container<String, Int>.Compute_B1<any Error>(key: "test")
    print("B1: key=\(c.key)")
    let _: Int.Type = type(of: c).Value.self
}
#endif

// MARK: - Variant B2: _Value capture for Compute
// Hypothesis: Use _Value to explicitly satisfy the associated type.
// Result: CONFIRMED — Build Succeeded, runtime: key=test, Value=Int
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

#if VARIANT_B2
extension Container {
    struct Compute_B2<E: Error & Sendable>: EffectProtocol {
        typealias Value = _Value
        typealias Failure = E

        let key: Key
        var arguments: Key { key }
    }
}

func testB2() {
    let c = Container<String, Int>.Compute_B2<any Error>(key: "test")
    print("B2: key=\(c.key)")
    let _: Int.Type = type(of: c).Value.self
}
#endif

// =============================================================================
// MARK: - Results Summary
// =============================================================================
//
// A0 (direct nesting):               REFUTED — Value shadows outer generic
// A1 (_Value capture):               CONFIRMED — outer generic accessible via _Value
// A2 (split decl/conformance):       REFUTED — typealias retroactively reinterprets
// A3 (explicit generic param):       CONFIRMED — works, poor ergonomics
// A4 (split + typealias Void):       REFUTED — same as A2
// B0 (direct nesting, no shadow):    REFUTED — compiler can't infer from outer scope
// B1 (typealias Value = Value):      REFUTED — circular reference
// B2 (_Value capture):               CONFIRMED — explicit alias breaks circularity
//
// Recommendation: Use _Value capture (A1 + B2). Single `typealias _Value = Value`
// on Cache enables both Evict and Compute nesting. Combined build+run verified.
//
// Key insight: Swift typealiases are structural, not lexical. A typealias added
// in a conformance extension retroactively reinterprets ALL uses of that name
// in the type, including stored properties declared before the conformance.
// The _Value workaround escapes this by introducing a name the protocol
// requirement cannot shadow.

// =============================================================================
// MARK: - Execution
// =============================================================================

print("Cache effect type nesting experiment")
print("Testing enabled variants...")

#if VARIANT_A1
print("--- Variant A1 ---")
let a1 = Container<String, Int>.Evict_A1(key: "k", value: 42, reason: "test")
print("A1: key=\(a1.key) value=\(a1.value) reason=\(a1.reason)")
let _: Void.Type = type(of: a1).Value.self
print("A1: EffectProtocol.Value = Void ✓")
#endif

#if VARIANT_A2
print("--- Variant A2 ---")
let a2 = Container<String, Int>.Evict_A2(key: "k", value: 42, reason: "test")
print("A2: key=\(a2.key) value=\(a2.value) reason=\(a2.reason)")
let _: Void.Type = type(of: a2).Value.self
print("A2: EffectProtocol.Value = Void ✓")
#endif

#if VARIANT_A3
print("--- Variant A3 ---")
testA3()
#endif

#if VARIANT_A4
print("--- Variant A4 ---")
let a4 = Container<String, Int>.Evict_A4(key: "k", value: 42, reason: "test")
print("A4: key=\(a4.key) value=\(a4.value) reason=\(a4.reason)")
let _: Void.Type = type(of: a4).Value.self
print("A4: EffectProtocol.Value = Void ✓")
#endif

#if VARIANT_A1 || VARIANT_A2 || VARIANT_A3 || VARIANT_A4
#else
print("(No A-variants enabled)")
#endif

#if VARIANT_B0
print("--- Variant B0 ---")
testB0()
#endif

#if VARIANT_B1
print("--- Variant B1 ---")
testB1()
#endif

#if VARIANT_B2
print("--- Variant B2 ---")
testB2()
#endif

#if VARIANT_B0 || VARIANT_B1 || VARIANT_B2
#else
print("(No B-variants enabled)")
#endif

print("Done.")
