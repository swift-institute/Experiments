// Status: SUPERSEDED -- Property<Tag,Base>.View.Typed<Element> pattern shipped in swift-property-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================
// EXPERIMENT: forEach Property.View with ~Copyable Elements
// ============================================================================
//
// HYPOTHESIS: Can we create a Property.View pattern that works for ~Copyable
//             elements without separate methods?
//
// APPROACH: [EXP-004a] Incremental Construction
//           Build up from simplest case to find limitations.
//
// STATUS: CONFIRMED
//
// RESULT: Property.View.Typed<Element: ~Copyable> works!
//         Use Property<Tag, Base>.View.Typed<Element> instead of Property<Tag, Base>.View
//         Extensions constrain Base == Container<Element> to access container internals
//         Copyable-only features (.consuming) go in separate extension with Element: Copyable
// ============================================================================

// MARK: - Test 1: Basic Property.View structure (no generics)

struct Tag1 {}

struct View1: ~Copyable {
    let base: UnsafeMutablePointer<Int>

    func callAsFunction(_ body: (Int) -> Void) {
        body(unsafe base.pointee)
    }
}

struct Container1: ~Copyable {
    var value: Int = 42

    var forEach: View1 {
        mutating _read {
            yield unsafe View1(base: &value)
        }
    }
}

func test1() {
    var c = Container1()
    c.forEach { print("Test1: \($0)") }  // Does this work?
}

// MARK: - Test 2: Generic container with Copyable element

struct View2<Base: ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>
}

extension View2 where Base == Container2<Int> {
    func callAsFunction(_ body: (Int) -> Void) {
        body(unsafe base.pointee.value)
    }
}

struct Container2<Element>: ~Copyable {
    var value: Element

    var forEach: View2<Self> {
        mutating _read {
            yield unsafe View2(base: &self)
        }
    }
}

func test2() {
    var c = Container2(value: 42)
    c.forEach { print("Test2: \($0)") }
}

// MARK: - Test 3: Protocol with associated type (standard approach)

protocol ForEachable3: ~Copyable {
    associatedtype Element  // Implicitly Copyable per SE-0427
    func _forEach(_ body: (borrowing Element) -> Void)
}

struct View3<Base: ForEachable3 & ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>

    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        unsafe base.pointee._forEach(body)
    }
}

struct Container3<Element>: ~Copyable {
    var value: Element
}

extension Container3: ForEachable3 where Element: Copyable {
    func _forEach(_ body: (borrowing Element) -> Void) {
        body(value)
    }

    var forEach: View3<Self> {
        mutating _read {
            yield unsafe View3(base: &self)
        }
    }
}

func test3() {
    var c = Container3(value: 42)
    c.forEach { print("Test3: \($0)") }
}

// MARK: - Test 4: Try ~Copyable element with protocol

// This tests if we can somehow get ~Copyable elements to work

struct MoveOnly: ~Copyable {
    var id: Int
}

// Can Container3 work with MoveOnly?
// extension Container3: ForEachable3 where Element == MoveOnly {
//     // Error: Element must be Copyable because ForEachable3.Element is Copyable
// }

// MARK: - Test 5: Type-specific view (no protocol needed)

struct Container5<Element: ~Copyable>: ~Copyable {
    var value: Element
}

extension Container5 where Element: ~Copyable {
    struct ForEachView: ~Copyable {
        let base: UnsafeMutablePointer<Container5<Element>>

        @inlinable
        func callAsFunction(_ body: (borrowing Element) -> Void) {
            body(unsafe base.pointee.value)
        }
    }

    var forEach: ForEachView {
        mutating _read {
            yield unsafe ForEachView(base: &self)
        }
    }
}

func test5Copyable() {
    var c = Container5(value: 42)
    c.forEach { print("Test5 Copyable: \($0)") }
}

func test5NonCopyable() {
    var c = Container5(value: MoveOnly(id: 99))
    c.forEach { print("Test5 NonCopyable: \($0.id)") }
}

// MARK: - Test 6: Adding .consuming to type-specific view

extension Container5.ForEachView where Element: Copyable {
    // consuming variant only available for Copyable elements
    func consuming(_ body: (Element) -> Void) {
        body(unsafe base.pointee.value)
        // In real impl: would clear the container
    }
}

func test6() {
    var c = Container5(value: 42)
    c.forEach.consuming { print("Test6 consuming: \($0)") }
}

// MARK: - Test 7: Can we make this work with the existing Property.View?

// The existing Property.View is:
// struct Property<Tag, Base: ~Copyable> {
//     struct View: ~Copyable {
//         internal let _base: UnsafeMutablePointer<Base>
//     }
// }

// The issue: callAsFunction needs to know the Element type.
// Extensions on Property.View need to constrain Base to a protocol
// that provides the Element associated type. But associated types
// can't be ~Copyable yet.

// CONCLUSION: We need type-specific Views for ~Copyable element support.
// The protocol-based Property.View approach cannot work until Swift
// supports `associatedtype Element: ~Copyable`.

// MARK: - Test 7: Property.View with Element type parameter

// What if Property.View carries the Element type as a parameter?

struct Property7<Tag, Base: ~Copyable, Element: ~Copyable> {
    struct View: ~Copyable {
        let base: UnsafeMutablePointer<Base>
    }
}

// Now we can extend View with Element in scope!
extension Property7<ForEachTag7, Container7<Int>, Int>.View {
    func callAsFunction(_ body: (borrowing Int) -> Void) {
        body(unsafe base.pointee.value)
    }
}

struct ForEachTag7 {}

struct Container7<Element: ~Copyable>: ~Copyable {
    var value: Element

    var forEach: Property7<ForEachTag7, Self, Element>.View {
        mutating _read {
            yield unsafe Property7<ForEachTag7, Self, Element>.View(base: &self)
        }
    }
}

// But can we write GENERIC extensions that work for ANY Element?
// extension Property7.View where Tag == ForEachTag7 {
//     func callAsFunction(_ body: (borrowing Element) -> Void) {
//         // Element is in scope!
//     }
// }

// Let's test:
extension Property7.View where Tag == ForEachTag7, Element: ~Copyable {
    func callAsFunctionGeneric(_ body: (borrowing Element) -> Void) {
        // Can we access the element?
        // We have Base, but how do we get from Base to Element?
        // We need Base to have a way to iterate...
        // This is the same problem as before - we need a protocol!
    }
}

// MARK: - Test 8: Protocol with ~Copyable constraint on Self, not Element

// What if the protocol doesn't have an Element associated type at all?
// Instead, the callAsFunction is defined on the concrete View type.

protocol Iterable8: ~Copyable {
    // No associated type!
    // The forEach property is defined per-type with its specific View
}

struct Container8<Element: ~Copyable>: ~Copyable, Iterable8 {
    var value: Element
}

// The View is defined in an extension where Element is available
extension Container8 where Element: ~Copyable {
    struct ForEachView8: ~Copyable {
        let base: UnsafeMutablePointer<Container8<Element>>

        func callAsFunction(_ body: (borrowing Element) -> Void) {
            body(unsafe base.pointee.value)
        }
    }

    var forEach: ForEachView8 {
        mutating _read {
            yield unsafe ForEachView8(base: &self)
        }
    }
}

// Can we add .consuming in a separate extension?
extension Container8.ForEachView8 where Element: Copyable {
    func consuming(_ body: (Element) -> Void) {
        body(unsafe base.pointee.value)
    }
}

struct MoveOnly8: ~Copyable {
    var id: Int
}

func test8Copyable() {
    var c = Container8(value: 42)
    c.forEach { print("Test8 Copyable: \($0)") }
    c.forEach.consuming { print("Test8 consuming: \($0)") }
}

func test8NonCopyable() {
    var c = Container8(value: MoveOnly8(id: 77))
    c.forEach { print("Test8 NonCopyable: \($0.id)") }
    // c.forEach.consuming { } // Should NOT be available - and it isn't!
}

// MARK: - Test 9: Using Property.View.Typed (simulating existing infrastructure)

// Simulate the existing Property.View.Typed from property-primitives
struct Property9<Tag, Base: ~Copyable> {
    struct View: ~Copyable {
        struct Typed<Element: ~Copyable>: ~Copyable {
            let base: UnsafeMutablePointer<Base>

            init(_ base: UnsafeMutablePointer<Base>) {
                unsafe self.base = base
            }
        }
    }
}

// Tag for forEach
struct ForEach9 {}

// Container with ~Copyable elements
struct Container9<Element: ~Copyable>: ~Copyable {
    var value: Element
}

// Property extension providing forEach
extension Container9 where Element: ~Copyable {
    var forEach: Property9<ForEach9, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property9<ForEach9, Self>.View.Typed(&self)
        }
    }
}

// Extension constrained to specific Base type
// This is the key pattern: we constrain Base == Container9<Element>
// so that we can access base.pointee.value
extension Property9.View.Typed
where Tag == ForEach9, Base == Container9<Element>, Element: ~Copyable {
    func callAsFunction(_ body: (borrowing Element) -> Void) {
        body(unsafe base.pointee.value)
    }

    // Add .consuming only for Copyable elements
}

extension Property9.View.Typed
where Tag == ForEach9, Base == Container9<Element>, Element: Copyable {
    func consuming(_ body: (Element) -> Void) {
        body(unsafe base.pointee.value)
    }
}

struct MoveOnly9: ~Copyable {
    var id: Int
}

func test9Copyable() {
    var c = Container9(value: 42)
    c.forEach { print("Test9 Copyable: \($0)") }
    c.forEach.consuming { print("Test9 consuming: \($0)") }
}

func test9NonCopyable() {
    var c = Container9(value: MoveOnly9(id: 88))
    c.forEach { print("Test9 NonCopyable: \($0.id)") }
    // c.forEach.consuming { } // NOT available for ~Copyable - correct!
}

// MARK: - Main

test1()
test2()
test3()
test5Copyable()
test5NonCopyable()
test6()
test8Copyable()
test8NonCopyable()
test9Copyable()
test9NonCopyable()

print("\nAll tests passed!")
