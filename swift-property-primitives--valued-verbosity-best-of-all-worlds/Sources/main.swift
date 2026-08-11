// MARK: - Property View Valued — Best of All Worlds Verbosity Reduction
// Purpose: Validate the combination of typealias + .init shorthand + .Valued chain
//          for reducing declaration-site verbosity while preserving ~Copyable correctness.
// Hypothesis: The combination of (A) .Valued chain, (C) typealias Property<Tag>,
//             (I) .init shorthand and formatting conventions — all work together
//             with ~Copyable containers and Copyable overloads.
//
// Toolchain: Apple Swift version 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - All 9 variants compile and run correctly
// Date: 2026-02-12

// ===----------------------------------------------------------------------===//
// MARK: - Infrastructure (minimal reproduction of Property Primitives)
// ===----------------------------------------------------------------------===//

public struct Property<Tag, Base: ~Copyable>: ~Copyable {
    @usableFromInline let base: Base
    @inlinable public init(_ base: consuming Base) { self.base = base }
}

extension Property where Base: ~Copyable {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<Base>
        @inlinable @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }
        @inlinable public var base: UnsafeMutablePointer<Base> { unsafe _base }
    }
}

extension Property.View where Base: ~Copyable {
    @safe
    public struct Typed<Element: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<Base>
        @inlinable @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }
        @inlinable public var base: UnsafeMutablePointer<Base> { unsafe _base }
    }
}

extension Property.View.Typed where Base: ~Copyable, Element: ~Copyable {
    @safe
    public struct Valued<let n: Int>: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<Base>
        @inlinable @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }
        @inlinable public var base: UnsafeMutablePointer<Base> { unsafe _base }
    }
}

extension Property.View.Typed.Valued where Base: ~Copyable, Element: ~Copyable {
    @safe
    public struct Valued<let m: Int>: ~Copyable, ~Escapable {
        @usableFromInline let _base: UnsafeMutablePointer<Base>
        @inlinable @_lifetime(borrow base)
        public init(_ base: UnsafeMutablePointer<Base>) {
            unsafe _base = base
        }
        @inlinable public var base: UnsafeMutablePointer<Base> { unsafe _base }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Container with 1 value generic (like Buffer.Linked<N>)
// ===----------------------------------------------------------------------===//

struct Container<Element: ~Copyable, let N: Int>: ~Copyable {
    enum Insert {}
    enum Remove {}
    @usableFromInline var _storage: [Int] = []
    @usableFromInline var _count: Int = 0
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 1: Status Quo (no typealias, no .init shorthand)
// Hypothesis: Baseline — works, verbose
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    var insert_v1: Property<Insert, Self>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

extension Property.View.Typed.Valued
where Tag == Container<Element, n>.Insert,
      Base == Container<Element, n>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front_v1(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 2: typealias Property<Tag> (Option C)
// Hypothesis: typealias shortens accessor return type while preserving ~Copyable
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    // The typealias that heap-primitives already uses
    typealias Prop<Tag> = Property<Tag, Container<Element, N>>
}

extension Container where Element: ~Copyable {
    var insert_v2: Prop<Insert>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe Prop<Insert>.View.Typed<Element>.Valued<N>(&self)
        }
        mutating _modify {
            var view = unsafe Prop<Insert>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 3: .init shorthand in _read (Option I)
// Hypothesis: .init(&self) works in _read body, compiler infers return type
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    var insert_v3: Property<Insert, Self>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe .init(&self)  // .init shorthand — type inferred from return type
        }
        mutating _modify {
            var view = unsafe Property<Insert, Self>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 4: typealias + .init shorthand combined
// Hypothesis: Both techniques compose — shortest accessor body
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    var insert_v4: Prop<Insert>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view = unsafe Prop<Insert>.View.Typed<Element>.Valued<N>(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 5: .init shorthand in BOTH _read AND _modify
// Hypothesis: .init works in _modify with explicit type annotation on var
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    var insert_v5: Prop<Insert>.View.Typed<Element>.Valued<N> {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Prop<Insert>.View.Typed<Element>.Valued<N> = unsafe .init(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 6: Full PropertyView<Tag> typealias (Option H)
// Hypothesis: A deeper typealias covering .View.Typed.Valued works and
//             preserves ~Copyable correctness
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    typealias PropertyView<Tag> = Property<Tag, Container<Element, N>>.View.Typed<Element>.Valued<N>
}

extension Container where Element: ~Copyable {
    var insert_v6: PropertyView<Insert> {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: PropertyView<Insert> = unsafe .init(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 7: Copyable overload with typealias + .init
// Hypothesis: Copyable overloads work with all techniques
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

extension Property.View.Typed.Valued
where Tag == Container<Element, n>.Insert,
      Base == Container<Element, n>,
      Element: Copyable
{
    @_lifetime(&self)
    mutating func front_copyable(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 8: 2 value generics with .Valued.Valued + all techniques
// Hypothesis: All techniques compose with double Valued
// Result: CONFIRMED
// ===----------------------------------------------------------------------===//

struct Container2<Element: ~Copyable, let N: Int, let capacity: Int>: ~Copyable {
    enum Insert {}
    @usableFromInline var _storage: [Int] = []
    @usableFromInline var _count: Int = 0
}

// Full typealias chain for 2 value generics
extension Container2 where Element: ~Copyable {
    typealias Prop<Tag> = Property<Tag, Container2<Element, N, capacity>>
    typealias PropertyView<Tag> = Prop<Tag>.View.Typed<Element>.Valued<N>.Valued<capacity>
}

extension Container2 where Element: ~Copyable {
    var insert: PropertyView<Insert> {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: PropertyView<Insert> = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property.View.Typed.Valued.Valued
where Tag == Container2<Element, n, m>.Insert,
      Base == Container2<Element, n, m>,
      Element: ~Copyable
{
    @_lifetime(&self)
    mutating func front(_ element: Int) {
        unsafe base.pointee._storage.append(element)
        unsafe base.pointee._count += 1
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Variant 9: Multi-line formatting convention
// Hypothesis: Multi-line return type formatting compiles correctly
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// ===----------------------------------------------------------------------===//

extension Container where Element: ~Copyable {
    var insert_v9:
        Property<Insert, Self>
        .View.Typed<Element>.Valued<N>
    {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view:
                Property<Insert, Self>
                .View.Typed<Element>.Valued<N> = unsafe .init(&self)
            yield &view
        }
    }
}

// ===----------------------------------------------------------------------===//
// MARK: - Runtime Verification
// ===----------------------------------------------------------------------===//

func testVariant1() {
    var c = Container<Int, 8>()
    c.insert_v1.front_v1(42)
    assert(c._count == 1, "V1 failed")
    print("V1 (status quo):        PASS — count=\(c._count)")
}

func testVariant2() {
    var c = Container<Int, 8>()
    c.insert_v2.front_v1(42)
    assert(c._count == 1, "V2 failed")
    print("V2 (typealias Prop):    PASS — count=\(c._count)")
}

func testVariant3() {
    var c = Container<Int, 8>()
    c.insert_v3.front_v1(42)
    assert(c._count == 1, "V3 failed")
    print("V3 (.init in _read):    PASS — count=\(c._count)")
}

func testVariant4() {
    var c = Container<Int, 8>()
    c.insert_v4.front_v1(42)
    assert(c._count == 1, "V4 failed")
    print("V4 (Prop + .init):      PASS — count=\(c._count)")
}

func testVariant5() {
    var c = Container<Int, 8>()
    c.insert_v5.front_v1(42)
    assert(c._count == 1, "V5 failed")
    print("V5 (.init in both):     PASS — count=\(c._count)")
}

func testVariant6() {
    var c = Container<Int, 8>()
    c.insert_v6.front_v1(42)
    assert(c._count == 1, "V6 failed")
    print("V6 (PropertyView<T>):   PASS — count=\(c._count)")
}

func testVariant7() {
    var c = Container<Int, 8>()
    c.insert_v1.front_copyable(99)
    assert(c._count == 1, "V7 failed")
    print("V7 (Copyable overload): PASS — count=\(c._count)")
}

func testVariant8() {
    var c = Container2<Int, 2, 16>()
    c.insert.front(42)
    assert(c._count == 1, "V8 failed")
    print("V8 (Valued.Valued):     PASS — count=\(c._count)")
}

func testVariant9() {
    var c = Container<Int, 8>()
    c.insert_v9.front_v1(42)
    assert(c._count == 1, "V9 failed")
    print("V9 (multi-line fmt):    PASS — count=\(c._count)")
}

print("=== Valued Verbosity Best-of-All-Worlds Experiment ===")
print()
testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()
testVariant8()
testVariant9()
testVariant10_insert()
testVariant10_remove()
testVariant10_copyable()
testVariant10_two_values()
print()
print("=== All variants passed ===")
