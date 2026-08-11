// ===----------------------------------------------------------------------===//
// TEST: Property.View for drain patterns with element ownership transfer
// ===----------------------------------------------------------------------===//
//
// QUESTION: Can Property.View support `.drain.consuming { }` syntax
//           where "consuming" means the CONTAINER is consumed (not just cleared)?
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: Property.View with element ownership transfer (drain semantics)

@safe
struct DrainView3<Base: ~Copyable>: ~Copyable, ~Escapable {
    @usableFromInline
    let ptr: UnsafeMutablePointer<Base>

    @inlinable
    @_lifetime(borrow ptr)
    init(_ ptr: UnsafeMutablePointer<Base>) {
        unsafe self.ptr = ptr
    }
}

struct Container3: ~Copyable {
    var elements: [Int] = [1, 2, 3]

    mutating func moveOutElement(at index: Int) -> Int {
        elements.remove(at: index)
    }

    var count: Int { elements.count }
}

extension DrainView3 where Base == Container3 {
    // Drain: move elements to closure, container survives empty
    @_lifetime(&self)
    @inlinable
    mutating func callAsFunction(_ body: (Int) -> Void) {
        // Move elements out one by one
        while unsafe ptr.pointee.count > 0 {
            let element = unsafe ptr.pointee.moveOutElement(at: 0)
            body(element)
        }
    }

    // Can we add a "consuming" variant that consumes the CONTAINER?
    // This would need to consume self, but self is just a View (pointer)
    // Consuming the View doesn't consume the container!
    //
    // @_lifetime(&self)
    // consuming func consuming(_ body: (Int) -> Void) {
    //     // We can consume self (the View), but...
    //     // ptr.pointee is still there! We can't consume it through a pointer.
    // }
}

extension Container3 {
    var drain: DrainView3<Self> {
        mutating _read {
            yield unsafe DrainView3(&self)
        }
        mutating _modify {
            var view = unsafe DrainView3(&self)
            yield &view
        }
    }
}

func testDrainView3() {
    print("\n=== Test: Property.View drain (element ownership) ===")
    var container = Container3()
    container.drain { element in
        print("  Moved out: \(element)")
    }
    print("  Container after drain: \(container.count) elements")
    print("  Container still usable: \(container.elements)")

    // Can we add more?
    container.elements.append(99)
    print("  After append: \(container.elements)")
}

// MARK: - Test 2: Can we get `.drain.consuming { }` to consume the container?

// The challenge: Property accessors return a View.
// Even if View has a `consuming func`, consuming the View doesn't consume the container.
//
// The container lives at a memory address. The View just points to it.
// There's no way to "consume" something through a pointer.

// What Property.Consuming does (for Copyable types):
// 1. Transfers the base OUT of self into a State object
// 2. The consuming method marks state as consumed
// 3. defer block checks: if consumed, don't restore self
//
// This requires Copyable because self must be replaced with a placeholder.

// For ~Copyable containers, there's no equivalent trick.
// The container can't be "temporarily moved out" during the accessor.

// MARK: - Test 3: Alternative - .drain().forEach { } pattern

struct ConsumingDrainResult3: ~Copyable {
    var elements: [Int]

    consuming func forEach(_ body: (Int) -> Void) {
        for element in elements {
            body(element)
        }
    }
}

extension Container3 {
    // consuming func that returns something iterable
    consuming func consumingDrain() -> ConsumingDrainResult3 {
        ConsumingDrainResult3(elements: elements)
    }
}

func testConsumingDrainMethod3() {
    print("\n=== Test: .consumingDrain().forEach { } pattern ===")
    let container = Container3()
    container.consumingDrain().forEach { element in
        print("  Consumed: \(element)")
    }
    print("  Container is consumed (variable gone)")
}

// MARK: - Test 4: The `.consuming().forEach { }` pattern (from Property.Consuming docs)

// This pattern follows naming conventions!
// - `.consuming()` returns a consuming view
// - `.forEach { }` operates on that view
// NOT compound - it's path-like composition!

struct Container3ConsumingView: ~Copyable {
    var elements: [Int]

    consuming func forEach(_ body: (Int) -> Void) {
        for element in elements {
            body(element)
        }
    }
}

extension Container3 {
    // This is the recommended pattern for ~Copyable containers
    consuming func consuming() -> Container3ConsumingView {
        Container3ConsumingView(elements: elements)
    }
}

func testConsumingNamespacePattern() {
    print("\n=== Test: .consuming().forEach { } pattern (recommended) ===")
    let container = Container3()
    container.consuming().forEach { element in
        print("  Consumed: \(element)")
    }
    print("  Container consumed via .consuming().forEach pattern")
    print("  This follows Nest.Name: consuming() returns view, forEach operates on it")
}

// MARK: - Conclusion

func testPropertyConsuming() {
    testDrainView3()
    testConsumingDrainMethod3()
    testConsumingNamespacePattern()

    print("\n=== Property.View Analysis ===")
    print("""
    Property.View CAN support:
    - .drain { } with element ownership transfer (mutating, container survives)
    - .forEach.consuming { } with borrow-then-clear (mutating, container survives empty)

    Property.View CANNOT support:
    - True container consumption where variable becomes unusable

    BUT: The `.consuming().forEach { }` pattern DOES work and follows naming!

    | Pattern | Naming | Works for ~Copyable? |
    |---------|--------|---------------------|
    | consumingForEach { }         | Compound ❌    | Yes |
    | .consuming().forEach { }     | Path-like ✅   | Yes |
    | .forEach.consuming { }       | Path-like ✅   | No (Property.Consuming requires Copyable) |

    RECOMMENDATION: Use `.consuming().forEach { }` pattern for ~Copyable containers.
    This follows [API-NAME-002] Nest.Name and works with consuming semantics.
    """)
}
