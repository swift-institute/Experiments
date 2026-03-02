// MARK: - ~Copyable Default Forwarding Investigation
// Purpose: Investigate why protocol default `testValue { liveValue }` fails for
//          ~Copyable values, and identify the precise boundary and solutions.
// Hypothesis: The constraint is specific to protocol PROPERTY access on generic
//             ~Copyable types, not to functions or concrete types.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
// Features: SuppressedAssociatedTypes, SuppressedAssociatedTypesWithDefaults
//
// Result: CONFIRMED — Root cause identified. Protocol property access (`{ get }`)
//         on ~Copyable associated types dispatches through `_read` coroutines in
//         the protocol witness table, yielding BORROWED values. Protocol function
//         calls return OWNED values. Concrete type property access (no witness
//         table) returns OWNED. This is a semantic consequence of Swift's property
//         dispatch model, not a bug.
//
//         The boundary: any code that accesses a PROTOCOL-REQUIRED PROPERTY on a
//         generic/associated ~Copyable type receives a borrow. Functions return owned.
//         The target (property, function, let binding) does not matter.
//
// Solutions ranked:
//   A. Constrain default to `where Value: Copyable` (current approach — simplest)
//   B. Change protocol requirements from properties to functions (API change)
//   C. Dual interface: properties for API, functions for forwarding (additive)
//   D. Conformer-level forwarding — each conformer provides explicit impls
//
// Date: 2026-02-24

struct UniqueHandle: ~Copyable, Sendable {
    let id: Int
    deinit { print("  UniqueHandle(\(id)) destroyed") }
}

// ============================================================================
// MARK: - Variant 1: Concrete type property → property (WORKS)
// Hypothesis: Without protocol dispatch, property → property works for ~Copyable.
// Result: CONFIRMED — concrete type getter returns owned value, not borrowed.
// ============================================================================

struct ConcreteForwarding {
    static var primary: UniqueHandle { UniqueHandle(id: 1) }
    static var secondary: UniqueHandle { primary }
}

// ============================================================================
// MARK: - Variant 2: Protocol property → property default (FAILS)
// Error: "'self.liveValue' is borrowed and cannot be consumed"
// Result: CONFIRMED fails — this is the core constraint.
// ============================================================================

protocol KeyPropertyProperty: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static var liveValue: Value { get }
    static var testValue: Value { get }
}

// ❌ FAILS: 'self.liveValue' is borrowed and cannot be consumed
// extension KeyPropertyProperty {
//     static var testValue: Value { liveValue }
// }

// ✅ Works when constrained:
extension KeyPropertyProperty where Value: Copyable {
    static var testValue: Value { liveValue }
}

// ============================================================================
// MARK: - Variant 3: Protocol function → property SOURCE (FAILS)
// Result: CONFIRMED fails — changing the TARGET to a function doesn't help.
//         The SOURCE (protocol property) produces the borrow.
// ============================================================================

// ❌ FAILS: 'self.liveValue' is borrowed and cannot be consumed
// protocol KeyFuncProperty: Sendable {
//     associatedtype Value: ~Copyable & Sendable = Self
//     static var liveValue: Value { get }
//     static func makeTestValue() -> Value
// }
// extension KeyFuncProperty {
//     static func makeTestValue() -> Value { liveValue }
// }

// ============================================================================
// MARK: - Variant 4: Protocol property ← function SOURCE (WORKS)
// Result: CONFIRMED — function source produces owned value. Property target
//         can consume it.
// ============================================================================

protocol KeyPropertyFunc: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static func makeLiveValue() -> Value
    static var testValue: Value { get }
}

extension KeyPropertyFunc {
    static var testValue: Value { makeLiveValue() }
}

struct HandleV4: KeyPropertyFunc, Sendable {
    typealias Value = UniqueHandle
    static func makeLiveValue() -> UniqueHandle { UniqueHandle(id: 4) }
}

// ============================================================================
// MARK: - Variant 5: Protocol function ← function (WORKS)
// Result: CONFIRMED — function → function forwarding works for ~Copyable.
// ============================================================================

protocol KeyFuncFunc: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static func makeLiveValue() -> Value
    static func makeTestValue() -> Value
}

extension KeyFuncFunc {
    static func makeTestValue() -> Value { makeLiveValue() }
}

struct HandleV5: KeyFuncFunc, Sendable {
    typealias Value = UniqueHandle
    static func makeLiveValue() -> UniqueHandle { UniqueHandle(id: 5) }
}

// ============================================================================
// MARK: - Variant 6: `consume` keyword (FAILS)
// Error: "'consume' can only be used to partially consume storage"
// Result: CONFIRMED fails — `consume` operates on stored properties, not
//         computed properties. Protocol property access is computed.
// ============================================================================

// ❌ FAILS: 'consume' can only be used to partially consume storage
// protocol KeyConsume: Sendable {
//     associatedtype Value: ~Copyable & Sendable = Self
//     static var liveValue: Value { get }
//     static var testValue: Value { get }
// }
// extension KeyConsume {
//     static var testValue: Value { consume liveValue }
// }

// ============================================================================
// MARK: - Variant 7: Free generic function ← property (FAILS)
// Result: CONFIRMED fails — not protocol-extension specific. ANY generic
//         context accessing a protocol property on ~Copyable gets a borrow.
// ============================================================================

// ❌ FAILS: 'unknown' is borrowed and cannot be consumed
// func forward<K: KeyPropertyProperty>(_ key: K.Type) -> K.Value {
//     K.liveValue
// }

// ============================================================================
// MARK: - Variant 8: Intermediate `let` binding (FAILS)
// Result: CONFIRMED fails — `let value = liveValue` also borrows.
//         The binding doesn't change ownership semantics.
// ============================================================================

// ❌ FAILS: 'self.liveValue' is borrowed and cannot be consumed
// protocol KeyLetBinding: Sendable {
//     associatedtype Value: ~Copyable & Sendable = Self
//     static var liveValue: Value { get }
//     static var testValue: Value { get }
// }
// extension KeyLetBinding {
//     static var testValue: Value {
//         let value = liveValue
//         return value
//     }
// }

// ============================================================================
// MARK: - Variant 9: Concrete generic struct (WORKS)
// Result: CONFIRMED — generic parameter doesn't cause borrow. Only protocol
//         witness table dispatch does.
// ============================================================================

struct Factory<T: ~Copyable & Sendable>: Sendable {
    var make: @Sendable () -> T
    var primary: T { make() }
    var secondary: T { primary }
}

// ============================================================================
// MARK: - Variant 10: Dual interface — property + function (WORKS)
// Result: CONFIRMED — Properties for API, functions for forwarding.
//         Defaults use func→func chain. Conformers provide both.
// ============================================================================

protocol KeyDual: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static var liveValue: Value { get }
    static func makeLiveValue() -> Value
    static var testValue: Value { get }
    static func makeTestValue() -> Value
}

// ❌ Cannot bridge function → property:
// extension KeyDual {
//     static func makeLiveValue() -> Value { liveValue }
// }

// ✅ Property defaults from function, function defaults from function:
extension KeyDual {
    static func makeTestValue() -> Value { makeLiveValue() }
    static var testValue: Value { makeLiveValue() }
}

struct HandleV10: KeyDual, Sendable {
    typealias Value = UniqueHandle
    static var liveValue: UniqueHandle { UniqueHandle(id: 10) }
    static func makeLiveValue() -> UniqueHandle { UniqueHandle(id: 10) }
}

// ============================================================================
// MARK: - Variant 11: Closure indirection (WORKS)
// Result: CONFIRMED — Calling a closure (function type) returns owned.
//         The closure captures the property access at the conformer level.
// ============================================================================

protocol KeyClosure: Sendable {
    associatedtype Value: ~Copyable & Sendable = Self
    static var liveValue: Value { get }
    static var testValue: Value { get }
    static var makeLiveValue: @Sendable () -> Value { get }
}

extension KeyClosure {
    static var testValue: Value { makeLiveValue() }
}

struct HandleV11: KeyClosure, Sendable {
    typealias Value = UniqueHandle
    static var liveValue: UniqueHandle { UniqueHandle(id: 11) }
    static var makeLiveValue: @Sendable () -> UniqueHandle { { liveValue } }
}

// ============================================================================
// MARK: - Variant 12: Conformer-level forwarding (WORKS)
// Result: CONFIRMED — When the conformer provides the property directly,
//         it accesses its own concrete getter (no witness table).
// ============================================================================

struct HandleV12: KeyPropertyProperty, Sendable {
    typealias Value = UniqueHandle
    static var liveValue: UniqueHandle { UniqueHandle(id: 12) }
    static var testValue: UniqueHandle { liveValue }
}

// ============================================================================
// MARK: - Variant 13: Instance property → property (FAILS)
// Result: CONFIRMED fails — same issue on instance properties. Not static-specific.
// ============================================================================

// ❌ FAILS: 'self.primary' is borrowed and cannot be consumed
// protocol InstancePropertyProperty: Sendable {
//     associatedtype Value: ~Copyable & Sendable
//     var primary: Value { get }
//     var secondary: Value { get }
// }
// extension InstancePropertyProperty {
//     var secondary: Value { primary }
// }

// ============================================================================
// MARK: - Variant 14: Instance function → function (WORKS)
// Result: CONFIRMED — function → function works on instance methods too.
// ============================================================================

// ✅ WORKS
// protocol InstanceFuncFunc: Sendable {
//     associatedtype Value: ~Copyable & Sendable
//     func makePrimary() -> Value
//     func makeSecondary() -> Value
// }
// extension InstanceFuncFunc {
//     func makeSecondary() -> Value { makePrimary() }
// }

// ============================================================================
// MARK: - Variant 15: Free generic function ← protocol function (WORKS)
// Result: CONFIRMED — function access through generics returns owned.
// ============================================================================

func forwardFunc<K: KeyFuncFunc>(_ key: K.Type) -> K.Value {
    K.makeLiveValue()
}

struct HandleV15: KeyFuncFunc, Sendable {
    typealias Value = UniqueHandle
    static func makeLiveValue() -> UniqueHandle { UniqueHandle(id: 15) }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("Variant 1: Concrete struct property → property forwarding")
do {
    let h = ConcreteForwarding.secondary
    print("  secondary.id = \(h.id)")
}

print("\nVariant 4: Protocol property ← function source")
do {
    let h = HandleV4.testValue
    print("  testValue.id = \(h.id)")
}

print("\nVariant 5: Protocol function ← function")
do {
    let h = HandleV5.makeTestValue()
    print("  makeTestValue().id = \(h.id)")
}

print("\nVariant 9: Concrete generic struct property forwarding")
do {
    let factory = Factory<UniqueHandle>(make: { UniqueHandle(id: 9) })
    let h = factory.secondary
    print("  secondary.id = \(h.id)")
}

print("\nVariant 10: Dual interface — function → function forwarding")
do {
    let h = HandleV10.testValue
    print("  testValue.id = \(h.id)")
    let h2 = HandleV10.makeTestValue()
    print("  makeTestValue().id = \(h2.id)")
}

print("\nVariant 11: Closure indirection")
do {
    let h = HandleV11.testValue
    print("  testValue.id = \(h.id)")
}

print("\nVariant 12: Conformer-level forwarding")
do {
    let h = HandleV12.testValue
    print("  testValue.id = \(h.id)")
}

print("\nVariant 15: Free generic function ← protocol function")
do {
    let h = forwardFunc(HandleV15.self)
    print("  forwardFunc().id = \(h.id)")
}

print("\nAll variants complete.")

// ============================================================================
// MARK: - Results Summary
//
// ROOT CAUSE: Protocol property access (`static var x: T { get }`) on generic
// ~Copyable associated types dispatches through the protocol witness table's
// `_read` coroutine, which yields a BORROWED value. A borrow cannot be consumed
// (returned, assigned to let, etc.). Protocol function calls dispatch through
// the witness table's function entry, which returns an OWNED value.
//
// This affects:
//   - Static and instance properties equally
//   - Protocol extensions AND free generic functions
//   - All attempts at indirection (`let`, `consume`, closures-on-property)
//
// This does NOT affect:
//   - Concrete type property access (no witness table → owned return)
//   - Protocol function access (witness table → owned return)
//   - Concrete generic types without protocol dispatch
//   - Conformer-level property implementations (concrete type, not generic)
//
// Variant matrix:
//   Source: Protocol PROPERTY  → ❌ borrow (V2, V3, V6, V7, V8, V13)
//   Source: Protocol FUNCTION  → ✅ owned  (V4, V5, V14, V15)
//   Source: Concrete property  → ✅ owned  (V1, V9, V12)
//   Source: Closure call       → ✅ owned  (V11)
//
// Solutions (for Witness.Key `testValue { liveValue }` default chain):
//
// A. CONSTRAIN default to `where Value: Copyable` [CURRENT APPROACH]
//    Pro: Zero API change. ~Copyable conformers provide explicit impls.
//    Con: Each ~Copyable conformer must implement all three properties.
//    Assessment: Simplest. Correct for current use case.
//
// B. CHANGE protocol requirements from properties to functions
//    `static func makeLiveValue() -> Value` instead of `static var liveValue`
//    Pro: Default forwarding works universally.
//    Con: Breaking API change. Loses property syntax.
//    Assessment: Wrong trade-off — property syntax is the expected DI pattern.
//
// C. DUAL INTERFACE: keep properties, add functions, defaults use functions
//    Pro: Property syntax preserved. Default chain works via func → func.
//    Con: Each conformer provides 6 members (3 properties + 3 functions).
//    Assessment: Too much boilerplate per conformer.
//
// D. CLOSURE INDIRECTION: protocol adds factory closure requirement
//    `static var makeLiveValue: @Sendable () -> Value { get }`
//    Pro: Default works. Conformers provide closure wrapping property.
//    Con: Unnatural API. Closure creation overhead.
//    Assessment: Viable but awkward.
//
// RECOMMENDATION: Solution A (constrain to Copyable). The constraint is
// semantically correct — it says "forwarding between getters requires the
// ability to copy." ~Copyable conformers don't lose anything meaningful;
// they must provide explicit factory implementations per mode, which is
// the right design anyway since each mode typically constructs a different
// unique resource.
//
// This is NOT a compiler bug. It's a consequence of Swift's property dispatch
// model: protocol witness tables use `_read` coroutines for properties
// (yielding borrows) vs direct function returns for methods (transferring
// ownership). The distinction is invisible for Copyable types (borrow + copy
// = effectively owned) but surfaces for ~Copyable types.
// ============================================================================
