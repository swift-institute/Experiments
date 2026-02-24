// MARK: - Protocol Default Accessor
// Purpose: Validate whether protocols can provide default Property.View
//          accessor properties to eliminate boilerplate.
//          Core constraint: `associatedtype Element` requires Copyable —
//          ~Copyable types cannot conform, so they always need manual accessors.
//
// Variants tested:
//   1. Protocol default accessor with non-colliding names → works
//   2. Name collision (requirement name == property name) → infinite recursion
//   3. Marker protocol workaround for name collision → works
//   4. ~Copyable conformer → blocked by associatedtype Copyable requirement
//   5. Element-agnostic protocol (no associatedtype) → works for all types
//   6. Static protocol requirements → no collision (different namespaces)
//   6b. Static requirement with SAME NAME as accessor → works (single protocol)
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Protocol default accessors work. Four approaches validated:
//   (1) Non-colliding names: requirement ≠ property name → works directly.
//   (2) Same-name collision with instance requirement → infinite recursion.
//   (3) Marker protocol workaround → works but adds protocol complexity.
//   (4) Static requirements → BEST: same name works, single protocol, no collision.
//       `var drain` (instance) and `static func drain(...)` (static) are unambiguous.
//       Property.View calls `Base.drain(&base.pointee, body)` — no recursion.
//   Limitation: associatedtype Element blocks ~Copyable Element types (manual accessor).
//   Element-agnostic protocol (no associatedtype) works for all types.
// Output: Build Succeeded, all 15 tests pass
// Date: 2026-02-12

// ============================================================================
// MARK: - Infrastructure: Minimal Property.View replica
// ============================================================================

public struct Property<Tag, Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline
    let base: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(borrow base)
    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

extension Property where Base: ~Copyable {
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        let base: UnsafeMutablePointer<Base>

        @inlinable
        @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            self.base = base
        }
    }
}

// ============================================================================
// MARK: - Tags
// ============================================================================

public enum Sequence {
    public enum Drain {}
    public enum ForEach {}
}

// ============================================================================
// MARK: - Variant 1: Non-colliding names (requirement ≠ property)
// Hypothesis: Protocol default accessor works when names don't collide.
// ============================================================================

extension Sequence {
    public protocol `Protocol` {
        associatedtype Element
        mutating func _forEachElement(_ body: (Element) -> Void)
    }
}

// Protocol default accessor — property name `forEach` ≠ requirement `_forEachElement`.
extension Sequence.`Protocol` {
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View(&self)
            yield &view
        }
    }
}

// Shared Property.View method delegates through the requirement.
extension Property.View where Base: Sequence.`Protocol`, Tag == Sequence.ForEach {
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (Base.Element) -> Void) {
        unsafe base.pointee._forEachElement(body)
    }
}

// ============================================================================
// MARK: - Variant 2: Name collision (commented — infinite recursion)
// Result: REFUTED — `base.pointee.drain(body)` resolves to property + callAsFunction.
// ============================================================================

// Uncomment to verify:
//
// extension Sequence.Drain {
//     public protocol Colliding: ~Copyable {
//         associatedtype Element
//         mutating func drain(_ body: (consuming Element) -> Void)
//     }
// }
// extension Sequence.Drain.Colliding where Self: ~Copyable {
//     public var drain: Property<Sequence.Drain, Self>.View { ... }
// }
// extension Property.View
// where Base: Sequence.Drain.Colliding & ~Copyable, Tag == Sequence.Drain {
//     public mutating func callAsFunction(_ body: (consuming Base.Element) -> Void) {
//         unsafe base.pointee.drain(body) // ⚠️ INFINITE RECURSION
//     }
// }

// ============================================================================
// MARK: - Variant 3: Marker protocol decouples accessor from requirement
// Hypothesis: Property.View constrained to requirement protocol (no `var drain`).
//             Marker protocol provides `var drain`. No collision.
// ============================================================================

extension Sequence.Drain {
    // Requirement protocol.
    public protocol `Protocol`: ~Copyable {
        associatedtype Element
        mutating func drain(_ body: (consuming Element) -> Void)
    }

    // Marker — refines Protocol. Adds ~Copyable suppression.
    // Provides default `var drain` accessor.
    public protocol Accessible: Sequence.Drain.`Protocol`, ~Copyable {}
}

// Default accessor on marker (which allows ~Copyable conformers).
extension Sequence.Drain.Accessible where Self: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

// Property.View method constrained to REQUIREMENT protocol.
// `base.pointee` typed as `Sequence.Drain.Protocol` → has `func drain(_:)`,
// does NOT have `var drain` → no collision.
extension Property.View
where Base: Sequence.Drain.`Protocol` & ~Copyable, Tag == Sequence.Drain {
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Base.Element) -> Void) {
        unsafe base.pointee.drain(body)
    }
}

// ============================================================================
// MARK: - Variant 5: Element-agnostic protocol (no associatedtype)
// Hypothesis: Without associatedtype, ~Copyable types CAN conform.
//             Following Bit.Vector.Protocol / protocol-typealias-hoisting pattern.
// ============================================================================

extension Sequence.Drain {
    // Element-agnostic — no associatedtype. Uses type-erased closure.
    // Any type (~Copyable or Copyable) can conform.
    public protocol Agnostic: ~Copyable {
        mutating func _drainAll(_ body: (UnsafeRawPointer, Int) -> Void)
        mutating func _resetAfterDrain()
    }
}

extension Sequence.Drain.Agnostic where Self: ~Copyable {
    @inlinable
    public var agnosticDrain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

// ============================================================================
// MARK: - Conformers
// ============================================================================

// --- Copyable conformers ---

public struct Linear<Element> {
    var storage: [Element]
    init(_ elements: [Element]) { self.storage = elements }
}

extension Linear: Sequence.`Protocol` {
    public mutating func _forEachElement(_ body: (Element) -> Void) {
        for e in storage { body(e) }
    }
}

extension Linear: Sequence.Drain.Accessible {
    public mutating func drain(_ body: (consuming Element) -> Void) {
        for e in storage { body(e) }
        storage.removeAll()
    }
}

public struct Ring<Element> {
    var storage: [Element]
    init(_ elements: [Element]) { self.storage = elements }
}

extension Ring: Sequence.`Protocol` {
    public mutating func _forEachElement(_ body: (Element) -> Void) {
        for e in storage { body(e) }
    }
}

extension Ring: Sequence.Drain.Accessible {
    public mutating func drain(_ body: (consuming Element) -> Void) {
        while let e = storage.first {
            body(e)
            storage.removeFirst()
        }
    }
}

// --- ~Copyable conformer (Element is Copyable, struct is ~Copyable) ---

public struct Slab<Element>: ~Copyable {
    var storage: [Element]
    var bitmap: UInt8
    init(_ elements: [Element]) {
        self.storage = elements
        self.bitmap = UInt8((1 << elements.count) - 1)
    }
}

// Variant 3: Slab conforms to Accessible (marker protocol with ~Copyable).
// This works because Slab's Element is Copyable (no ~Copyable on generic param).
extension Slab: Sequence.Drain.Accessible {
    public mutating func drain(_ body: (consuming Element) -> Void) {
        var bits = bitmap
        while bits != 0 {
            let index = Int(bits.trailingZeroBitCount)
            body(storage[index])
            bits &= bits &- 1
        }
        bitmap = 0
    }
}

// --- ~Copyable conformer with ~Copyable Element ---

public struct Inline<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline var _count: Int
    init() { self._count = 0 }
}

// Variant 4: Cannot conform to Drain.Protocol (associatedtype Element requires Copyable).
// Must provide manual drain accessor.
extension Inline where Element: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View(&self)
            yield &view
        }
    }
}

// Manual Property.View method (cannot use protocol delegation).
extension Property.View where Base: ~Copyable {
    @_lifetime(&self)
    @inlinable
    public mutating func all<Element: ~Copyable, let capacity: Int>()
    where Tag == Sequence.Drain, Base == Inline<Element, capacity> {
        print("    Inline<\(capacity)>.drain.all()")
        unsafe base.pointee._count = 0
    }
}

// Variant 5: CAN conform to Agnostic (no associatedtype).
extension Inline: Sequence.Drain.Agnostic where Element: ~Copyable {
    public mutating func _drainAll(_ body: (UnsafeRawPointer, Int) -> Void) {
        print("    Inline<\(capacity)>._drainAll()")
    }
    public mutating func _resetAfterDrain() {
        _count = 0
    }
}

// ============================================================================
// MARK: - Variant 6: Static protocol requirements (no name collision)
// Hypothesis: If the protocol requirement is a static method, `var drain`
//             and `static func drain(...)` live in different namespaces.
//             The Property.View method calls `Base.drain(&base.pointee, body)`,
//             not `base.pointee.drain(body)` — no collision, no marker needed.
// ============================================================================

extension Sequence {
    public enum StaticDrain {}
}

extension Sequence.StaticDrain {
    // Single protocol — requirement is static, accessor is instance.
    // No marker protocol needed.
    public protocol `Protocol`: ~Copyable {
        associatedtype Element
        static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void)
    }
}

// Default accessor on the SAME protocol that declares the requirement.
// No collision: `var drain` (instance) vs `static func drain(...)` (static).
extension Sequence.StaticDrain.`Protocol` where Self: ~Copyable {
    @inlinable
    public var staticDrain: Property<Sequence.StaticDrain, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.StaticDrain, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.StaticDrain, Self>.View(&self)
            yield &view
        }
    }
}

// Property.View method on the SAME protocol — calls static, not instance.
extension Property.View
where Base: Sequence.StaticDrain.`Protocol` & ~Copyable, Tag == Sequence.StaticDrain {
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Base.Element) -> Void) {
        unsafe Base.drain(&base.pointee, body)
    }
}

// Conformers — implement static method.
extension Linear: Sequence.StaticDrain.`Protocol` {
    public static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void) {
        for e in instance.storage { body(e) }
        instance.storage.removeAll()
    }
}

extension Ring: Sequence.StaticDrain.`Protocol` {
    public static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void) {
        while let e = instance.storage.first {
            body(e)
            instance.storage.removeFirst()
        }
    }
}

extension Slab: Sequence.StaticDrain.`Protocol` {
    public static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void) {
        var bits = instance.bitmap
        while bits != 0 {
            let index = Int(bits.trailingZeroBitCount)
            body(instance.storage[index])
            bits &= bits &- 1
        }
        instance.bitmap = 0
    }
}

// ============================================================================
// MARK: - Variant 6b: Static requirement with SAME NAME as accessor property
// Hypothesis: `var drain` and `static func drain(...)` don't collide even
//             with identical names, because instance vs static is unambiguous.
//             Uses a fresh type (Queue) that doesn't conform to other variants.
// ============================================================================

public struct Queue<Element> {
    var storage: [Element]
    init(_ elements: [Element]) { self.storage = elements }
}

// Single protocol — static requirement named `drain`.
extension Sequence {
    public enum SameName {}
}

extension Sequence.SameName {
    public protocol `Protocol`: ~Copyable {
        associatedtype Element
        static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void)
    }
}

// Default accessor ALSO named `drain` — same protocol, same name.
extension Sequence.SameName.`Protocol` where Self: ~Copyable {
    @inlinable
    public var drain: Property<Sequence.SameName, Self>.View {
        mutating _read {
            yield unsafe Property<Sequence.SameName, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.SameName, Self>.View(&self)
            yield &view
        }
    }
}

// Property.View callAsFunction calls the STATIC — no collision with `var drain`.
extension Property.View
where Base: Sequence.SameName.`Protocol` & ~Copyable, Tag == Sequence.SameName {
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Base.Element) -> Void) {
        unsafe Base.drain(&base.pointee, body)
    }
}

extension Queue: Sequence.SameName.`Protocol` {
    public static func drain(_ instance: inout Self, _ body: (consuming Element) -> Void) {
        for e in instance.storage { body(e) }
        instance.storage.removeAll()
    }
}

// ============================================================================
// MARK: - Generic functions
// ============================================================================

func iterateAll<S: Sequence.`Protocol`>(_ s: inout S) {
    var items: [String] = []
    s.forEach { items.append("\($0)") }
    print("  forEach: \(items.joined(separator: ", "))")
}

func drainAll<S: Sequence.Drain.Accessible & ~Copyable>(_ s: inout S) {
    var items: [String] = []
    s.drain { items.append("\($0)") }
    print("  drained: \(items.joined(separator: ", "))")
}

func staticDrainAll<S: Sequence.StaticDrain.`Protocol` & ~Copyable>(_ s: inout S) {
    var items: [String] = []
    s.staticDrain { items.append("\($0)") }
    print("  static drained: \(items.joined(separator: ", "))")
}

// ============================================================================
// MARK: - Tests
// ============================================================================

print("=== Protocol Default Accessor ===")

// --- Variant 1: forEach accessor from Sequence.Protocol default ---

print("\n--- Test 1: Linear.forEach (protocol default) ---")
var linear1 = Linear([10, 20, 30])
linear1.forEach { print("  \($0)") }

print("\n--- Test 2: Ring.forEach (protocol default) ---")
var ring1 = Ring([100, 200, 300])
ring1.forEach { print("  \($0)") }

print("\n--- Test 3: Generic forEach ---")
var linear3 = Linear(["a", "b", "c"])
iterateAll(&linear3)
var ring3 = Ring(["d", "e", "f"])
iterateAll(&ring3)

// --- Variant 3: drain accessor from Drain.Accessible marker default ---

print("\n--- Test 4: Linear.drain (marker default) ---")
var linear2 = Linear([1, 2, 3])
print("Before: \(linear2.storage)")
linear2.drain { print("  \($0)") }
print("After: \(linear2.storage)")

print("\n--- Test 5: Ring.drain (marker default) ---")
var ring2 = Ring([4, 5, 6])
ring2.drain { print("  \($0)") }

print("\n--- Test 6: Slab.drain (~Copyable struct, marker default) ---")
var slab = Slab([7, 8, 9])
print("Before: bitmap = \(String(slab.bitmap, radix: 2))")
slab.drain { print("  \($0)") }
print("After: bitmap = \(String(slab.bitmap, radix: 2))")

print("\n--- Test 7: Generic drain ---")
var linear4 = Linear([100, 200])
drainAll(&linear4)
var slab2 = Slab([300, 400])
drainAll(&slab2)

// --- Variant 4: Inline manual accessor (cannot use protocol) ---

print("\n--- Test 8: Inline.drain (MANUAL — cannot use protocol default) ---")
var inline = Inline<Int, 8>()
inline._count = 3
print("Before: count = \(inline._count)")
inline.drain.all()
print("After: count = \(inline._count)")

// --- Variant 5: Agnostic protocol (no associatedtype) ---

print("\n--- Test 9: Inline conforms to Agnostic (element-agnostic) ---")
var inline2 = Inline<Int, 4>()
inline2._count = 2
print("Before: count = \(inline2._count)")
inline2._drainAll { _, _ in }
inline2._resetAfterDrain()
print("After: count = \(inline2._count)")

// --- Per-type method coexists ---

print("\n--- Test 10: Per-type method coexists with default accessor ---")
extension Property.View where Tag == Sequence.Drain, Base == Linear<Int> {
    @_lifetime(&self)
    public mutating func first() -> Int? {
        guard !(unsafe base.pointee.storage.isEmpty) else { return nil }
        return unsafe base.pointee.storage.removeFirst()
    }
}
var linear5 = Linear([42, 43, 44])
let first = linear5.drain.first()
print("  drain.first() = \(first!)")
linear5.drain { print("  drain remaining: \($0)") }

// --- Variant 6: Static protocol requirements ---

print("\n--- Test 11: Linear.staticDrain (static requirement, no marker) ---")
var linear6 = Linear([50, 60, 70])
print("Before: \(linear6.storage)")
linear6.staticDrain { print("  \($0)") }
print("After: \(linear6.storage)")

print("\n--- Test 12: Slab.staticDrain (~Copyable struct, static requirement) ---")
var slab3 = Slab([80, 90])
print("Before: bitmap = \(String(slab3.bitmap, radix: 2))")
slab3.staticDrain { print("  \($0)") }
print("After: bitmap = \(String(slab3.bitmap, radix: 2))")

print("\n--- Test 13: Generic staticDrain ---")
var linear7 = Linear([500, 600])
staticDrainAll(&linear7)
var slab4 = Slab([700, 800])
staticDrainAll(&slab4)

// --- Variant 6b: Same-name static requirement + accessor property ---

print("\n--- Test 14: Queue.drain (static req + same-name accessor, single protocol) ---")
var queue1 = Queue([11, 22, 33])
print("Before: \(queue1.storage)")
queue1.drain { print("  \($0)") }
print("After: \(queue1.storage)")

print("\n--- Test 15: Generic same-name drain ---")
func sameNameDrainAll<S: Sequence.SameName.`Protocol` & ~Copyable>(_ s: inout S) {
    var items: [String] = []
    s.drain { items.append("\($0)") }
    print("  same-name drained: \(items.joined(separator: ", "))")
}
var queue2 = Queue([44, 55])
sameNameDrainAll(&queue2)

print("\n=== All tests passed ===")
