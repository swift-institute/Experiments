// MARK: - Parameter Pack Concrete Extension Type Unwrapping
// Purpose: Determine whether concrete extensions of parameter-pack generic types
//          unwrap the pack, enabling positional tuple access and labeled accessors
// Hypothesis: The pack type (repeat each Element) is NOT unwrapped inside
//             concrete extensions — a known compiler limitation
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.2 (arm64)
//
// Result: REFUTED — blocked by known compiler limitation:
//         "same-type requirements between packs and concrete types are not yet supported"
//         (swiftlang/swift test/Generics/variadic_generic_types.swift:128)
//
//         The pack type is preserved inside extension bodies even when the extension
//         fully specifies concrete type arguments. Runtime type IS correct, but the
//         static type system doesn't narrow. Free functions and external
//         dynamicMemberLookup work as partial workarounds.
//
// Date: 2026-03-20

// ============================================================================
// Minimal infrastructure: parameter-pack generic type
// ============================================================================

@dynamicMemberLookup
struct Variadic<each Element> {
    var values: (repeat each Element)

    init(_ values: repeat each Element) {
        self.values = (repeat each values)
    }

    subscript<T>(dynamicMember keyPath: KeyPath<(repeat each Element), T>) -> T {
        values[keyPath: keyPath]
    }
}

extension Variadic: Sendable where repeat each Element: Sendable {}
extension Variadic: Equatable where repeat each Element: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        func check<T: Equatable>(_ l: T, _ r: T) -> Bool { l == r }
        for element in repeat (check((each lhs.values), (each rhs.values))) {
            guard element else { return false }
        }
        return true
    }
}

// ============================================================================
// MARK: - Variant 1: Concrete extension declaration
// Hypothesis: extension Variadic<Int, String, Double> { } compiles in 6.2.4
// Result: CONFIRMED — Build Succeeded
//         (was error in Swift 5.9: "same-type requirements between packs
//         and concrete types are not yet supported")
// ============================================================================

extension Variadic<Int, String, Double> {
    func selfType() -> String { "\(type(of: self))" }
    // Output: Variadic<Pack{Int, String, Double}>
}

// ============================================================================
// MARK: - Variant 2: Pack unwrapping inside concrete extension
// Hypothesis: values is unwrapped to the concrete tuple inside the extension
// Result: REFUTED — compiler still treats values as (repeat each Element)
//
// Three forms tested, all fail:
//
// 2a — Direct assignment:
//   Error: "pack expansion requires that 'each Element' and 'Int, String, Double'
//           have the same shape"
//   Command: swift build
//
// 2b — Positional access:
//   Error: "value pack expansion can only appear inside a function argument list,
//           tuple element, or as the expression of a for-in loop"
//   Command: swift build
//
// 2c — dynamicMemberLookup (self.0):
//   Error: "value of type 'Variadic<repeat each Element>' has no dynamic member
//           '0' using key path from root type '(repeat each Element)'"
//   Command: swift build
// ============================================================================

// UNCOMMENT ANY BLOCK TO VERIFY:

// 2a:
// extension Variadic<Int, String, Double> {
//     var first: Int {
//         let t: (Int, String, Double) = values  // ❌
//         return t.0
//     }
// }

// 2b:
// extension Variadic<Int, String, Double> {
//     var first: Int { values.0 }  // ❌
// }

// 2c:
// extension Variadic<Int, String, Double> {
//     var first: Int { self.0 }  // ❌
// }

// ============================================================================
// MARK: - Variant 3: Force cast workaround
// Hypothesis: values as! (concrete tuple) works at runtime
// Result: CONFIRMED — forced cast succeeds, positional access works after cast
// ============================================================================

extension Variadic<Int, String, Double> {
    func variant3() {
        let concrete = values as! (Int, String, Double)
        print("V3 — .0: \(concrete.0), .1: \(concrete.1), .2: \(concrete.2)")
        // Output: V3 — .0: 1, .1: hello, .2: 3.14
    }
}

// ============================================================================
// MARK: - Variant 4: Labeled accessors via as! in concrete extension
// Hypothesis: computed properties that cast internally provide labeled access
// Result: CONFIRMED — works, but requires unsafe as! and one extension per
//         concrete instantiation (cannot be generic)
// ============================================================================

extension Variadic<Int, String, Double> {
    private var concrete: (Int, String, Double) {
        values as! (Int, String, Double)
    }

    var number: Int { concrete.0 }
    var text: String { concrete.1 }
    var fraction: Double { concrete.2 }
}

func testVariant4() {
    let v = Variadic(42, "hello", 3.14)
    print("V4 — number: \(v.number), text: \(v.text), fraction: \(v.fraction)")
    // Output: V4 — number: 42, text: hello, fraction: 3.14
}

// ============================================================================
// MARK: - Variant 5: External dynamicMemberLookup
// Hypothesis: positional access (.0, .1) works at the call site
// Result: CONFIRMED — the caller knows the concrete tuple type and can
//         resolve keypaths; the extension body cannot
// ============================================================================

func testVariant5() {
    let v = Variadic(42, "hello", 3.14)
    let n: Int = v.0
    let t: String = v.1
    let f: Double = v.2
    print("V5 — .0: \(n), .1: \(t), .2: \(f)")
    // Output: V5 — .0: 42, .1: hello, .2: 3.14
}

// ============================================================================
// MARK: - Variant 6: Generic pack-shape extension
// Hypothesis: no syntax exists to extend a pack type for a specific pack shape
//             with unbound generic parameters
// Result: REFUTED — cannot introduce generic parameters in pack extension
//
// What we WANT:
//   extension Variadic<A, B> {          // A, B are unbound — no syntax
//       var first: A { ... }
//   }
//
// What the compiler test suite says (variadic_generic_types.swift:128):
//   extension WithPack<Int, Int> {}
//   // expected-error: same-type requirements between packs and concrete types
//   //                 are not yet supported
//
// The where-clause form also fails:
//   extension Variadic where (repeat each Element) == (Int, Int) {}
//   // expected-error: generic signature requires types to be the same
// ============================================================================

// ============================================================================
// MARK: - Variant 7: Free functions CAN constrain pack shapes
// Hypothesis: generic parameters at function level provide the unbound variables
//             that extensions cannot introduce
// Result: CONFIRMED — free functions resolve pack elements via their own generics
// ============================================================================

func first<A, B>(of v: Variadic<A, B>) -> A { v.0 }
func second<A, B>(of v: Variadic<A, B>) -> B { v.1 }

func first<A, B, C>(of v: Variadic<A, B, C>) -> A { v.0 }
func second<A, B, C>(of v: Variadic<A, B, C>) -> B { v.1 }
func third<A, B, C>(of v: Variadic<A, B, C>) -> C { v.2 }

func testVariant7() {
    let v2 = Variadic(42, "hello")
    print("V7 — first: \(first(of: v2)), second: \(second(of: v2))")
    // Output: V7 — first: 42, second: hello

    let v3 = Variadic(42, "hello", 3.14)
    print("V7 — first: \(first(of: v3)), third: \(third(of: v3))")
    // Output: V7 — first: 42, third: 3.14
}

// ============================================================================
// MARK: - Variant 8: Component-wise AdditiveArithmetic via pack iteration
// Hypothesis: generic pack constraints (where repeat each Element: P) work
//             for protocol conformances and pack-iterated operations
// Result: CONFIRMED — pack iteration for arithmetic compiles and runs
// ============================================================================

extension Variadic: AdditiveArithmetic where repeat each Element: AdditiveArithmetic {
    static var zero: Self {
        Self(repeat (each Element).zero)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(repeat (each lhs.values) + (each rhs.values))
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        Self(repeat (each lhs.values) - (each rhs.values))
    }
}

func testVariant8() {
    let a = Variadic(10, 20.0)
    let b = Variadic(1, 2.0)
    let sum = a + b
    let zero: Variadic<Int, Double> = .zero
    print("V8 — sum: (\(first(of: sum)), \(second(of: sum)))")
    print("V8 — zero: (\(first(of: zero)), \(second(of: zero)))")
    // Output: sum: (11, 22.0), zero: (0, 0.0)
}

// ============================================================================
// MARK: - Variant 9: Codable
// Hypothesis: parameter-pack Codable is not expressible
// Result: REFUTED — Codable for packs noted as "not directly expressible"
//         in Swift 6.2. Even if added, would produce unkeyed (array) encoding.
//         Domain-specific keyed encoding requires the generic extension (V6)
//         which is blocked.
// ============================================================================

func testVariant9() {
    print("V9 — Pack Codable not expressible. Keyed encoding blocked by V6.")
}

// ============================================================================
// MARK: - Application Example: Geometry.Insets
//
// A concrete use case that motivated this experiment. Geometry.Insets is a
// named struct with four properties (top: Height, leading: Width, bottom,
// trailing). The question was whether it could become a typealias to
// Product<Height, Width, Height, Width> with labeled accessors via extensions.
//
// This requires a generic pack-shape extension (V6) since Height/Width are
// themselves generic over Scalar and Space. V6 is blocked, so the typealias
// is not viable. Additional domain-specific blockers:
// - Custom keyed Codable ({"top":..., "leading":...}) requires V6
// - Functorial map across Scalar types requires V6
// - Convenience inits (init(all:), init(horizontal:vertical:)) require V6
//
// See: swift-primitives/swift-geometry-primitives Geometry.Insets.swift
// ============================================================================

// ============================================================================
// MARK: - Run all variants
// ============================================================================

print("=== V1: Concrete pack extension declaration ===")
let p1 = Variadic(1, "hello", 3.14)
print("V1 — selfType: \(p1.selfType())")

print("\n=== V3: Force cast workaround ===")
p1.variant3()

print("\n=== V4: Labeled accessors via as! ===")
testVariant4()

print("\n=== V5: External dynamicMemberLookup ===")
testVariant5()

print("\n=== V7: Free function accessors ===")
testVariant7()

print("\n=== V8: Component-wise arithmetic ===")
testVariant8()

print("\n=== V9: Codable ===")
testVariant9()

// ============================================================================
// MARK: - Results Summary
//
// V1 (concrete ext declaration):  CONFIRMED — compiles in 6.2.4 (was error in 5.9)
// V2 (pack unwrapping in ext):    REFUTED   — pack not unwrapped; three forms tested
// V3 (force cast workaround):     CONFIRMED — as! works at runtime (unsafe)
// V4 (concrete labeled getters):  CONFIRMED — works via as! (concrete-only, unsafe)
// V5 (external .0/.1 access):     CONFIRMED — dynamicMemberLookup at call site
// V6 (generic pack-shape ext):    REFUTED   — no syntax, known compiler limitation
// V7 (free function accessors):   CONFIRMED — generic constraints at function level
// V8 (component-wise arithmetic): CONFIRMED — pack iteration for protocol conformances
// V9 (Codable):                   REFUTED   — no pack Codable
//
// OVERALL: REFUTED (as of Swift 6.2.4)
//
// ROOT CAUSE: Known compiler limitation — "same-type requirements between packs
// and concrete types are not yet supported" (swiftlang/swift test/Generics/
// variadic_generic_types.swift:128). The pack type (repeat each Element) is not
// unwrapped to the concrete tuple inside extensions, even when the extension
// fully specifies concrete type arguments. The runtime type IS correct
// (type(of: self) shows Pack{...}), but the static type system doesn't narrow.
//
// WORKAROUNDS (with trade-offs):
//   1. Free functions: generic, safe — but free-function syntax, not dot syntax
//   2. Concrete extension + as!: dot syntax — but unsafe cast, per-instantiation
//   3. External dynamicMemberLookup: .0/.1 at call site — positional, not labeled
//
// IMPLICATION: Parameter-pack types are well-suited for generic algebraic
// composition (AdditiveArithmetic, Equatable, Hashable via pack iteration).
// They are NOT suited as replacements for named structs that need labeled
// properties, custom Codable, or domain-specific convenience APIs — those
// require the generic pack-shape extension (V6) that is blocked.
//
// When Swift lifts the same-type pack limitation, V2 and V6 should be retested.
// ============================================================================
