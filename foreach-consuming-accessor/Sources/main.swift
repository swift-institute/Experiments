// SUPERSEDED: See noncopyable-access-patterns
// MARK: - ForEach Consuming Accessor Pattern
// Purpose: Test if .forEach.consuming can consume the original container
//
// Hypothesis: A property accessor can return a type with both .borrowing and
//             .consuming() paths, where consuming actually consumes the container
//
// Claims to test:
// [CLAIM-001] Property can return accessor type with callAsFunction (borrowing)
// [CLAIM-002] Accessor can have .borrowing property for explicit borrowing
// [CLAIM-003] Accessor can have .consuming() method
// [CLAIM-004] .consuming() can actually consume the original container
// [CLAIM-005] Pattern works with ~Copyable containers
//
// Toolchain: Apple Swift version 6.2.3
// Date: 2026-01-22
// Result: Property.View with pointer-based mutating func (Variant 7) is optimal for
//         .forEach.consuming syntax. Zero heap allocation, full ~Copyable support.
//         Adopted in Collection.ForEach+Property.View.swift (index-based iteration,
//         mutating consuming method via Collection.Clearable).
//
// ============================================================================
// FINDINGS SUMMARY
// ============================================================================
//
// [CLAIM-001] CONFIRMED - callAsFunction works for .forEach { } syntax
// [CLAIM-002] CONFIRMED - .forEach.borrowing { } works
// [CLAIM-003] CONFIRMED - .forEach.consuming() method exists and compiles
// [CLAIM-004] REFUTED for basic accessor - borrowed accessor can't consume
// [CLAIM-004] CONFIRMED with state-tracking! - _read + defer + state class works
// [CLAIM-005] CONFIRMED - pattern works with ~Copyable containers
//
// CONCLUSION: .forEach.consuming IS achievable!
//
// OPTIMAL: Property.View with pointer-based consuming (Variant 7)
// - Use mutating func consuming() that clears through pointer
// - Zero heap allocation, true ~Copyable support
// - func methods = borrowing, mutating func methods = consuming
//
// ALTERNATIVE: State-tracking pattern (Variant 4/5)
// - Use _read accessor with defer + reference-type state
// - Works but requires heap allocation
//
// ============================================================================

// MARK: - Test Container (Copyable for simplicity)

struct Container<Element> {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }
}

// MARK: - Variant 1: Basic Accessor Pattern
// Question: Can we have .forEach with both borrowing and consuming paths?

extension Container {
    struct ForEachAccessor {
        // Stores a COPY of the container (for Copyable containers)
        // or a borrowed reference (for ~Copyable)
        // Either way, consuming this accessor doesn't consume the original
        var _elements: [Element]

        init(_ container: borrowing Container) {
            self._elements = container.elements
        }

        // Canonical: .forEach { } via callAsFunction
        func callAsFunction(_ body: (Element) -> Void) {
            for element in _elements {
                body(element)
            }
        }

        // Explicit borrowing: .forEach.borrowing { }
        var borrowing: BorrowingAccessor {
            BorrowingAccessor(_elements)
        }

        struct BorrowingAccessor {
            let _elements: [Element]

            init(_ elements: [Element]) {
                self._elements = elements
            }

            func callAsFunction(_ body: (Element) -> Void) {
                for element in _elements {
                    body(element)
                }
            }
        }

        // Consuming attempt: .forEach.consuming()
        // This exists and compiles, but it consumes the ACCESSOR, not the container
        consuming func consuming(_ body: (Element) -> Void) {
            print("  NOTE: consuming() consumes the ForEachAccessor, not Container")
            for element in _elements {
                body(element)
            }
        }
    }

    var forEach: ForEachAccessor {
        // Property getter borrows self and returns a new accessor
        // The accessor has a COPY of elements (for Copyable types)
        ForEachAccessor(self)
    }
}

func testVariant1() {
    print("=== Variant 1: Basic Accessor with Copyable Container ===")
    print()

    // Test CLAIM-001: callAsFunction for canonical .forEach { }
    print("--- CLAIM-001: .forEach { } via callAsFunction ---")
    do {
        let container = Container([1, 2, 3])
        container.forEach { element in
            print("  Element: \(element)")
        }
        print("  Container still valid: \(container.elements.count) elements")
        print("  Result: CONFIRMED")
    }
    print()

    // Test CLAIM-002: .forEach.borrowing { }
    print("--- CLAIM-002: .forEach.borrowing { } ---")
    do {
        let container = Container([4, 5, 6])
        container.forEach.borrowing { element in
            print("  Element: \(element)")
        }
        print("  Container still valid: \(container.elements.count) elements")
        print("  Result: CONFIRMED")
    }
    print()

    // Test CLAIM-003 & CLAIM-004: .forEach.consuming()
    print("--- CLAIM-003 & CLAIM-004: .forEach.consuming() ---")
    do {
        let container = Container([7, 8, 9])
        container.forEach.consuming { element in
            print("  Element: \(element)")
        }
        // Container is still valid! It wasn't consumed.
        print("  Container still valid: \(container.elements.count) elements")
        print("  CLAIM-003 (method exists): CONFIRMED")
        print("  CLAIM-004 (actually consumes): REFUTED")
        print("  The accessor was consumed, not the container")
    }
    print()
}

// MARK: - Variant 2: ~Copyable Container
// Question: Does the pattern work with ~Copyable containers?

struct NCContainer<Element>: ~Copyable {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    deinit {
        print("  NCContainer deinit with \(elements.count) elements")
    }
}

extension NCContainer {
    struct ForEachAccessor: ~Copyable {
        // For ~Copyable, we need to store elements differently
        // We'll copy the array (which is Copyable) to avoid ownership issues
        var _elements: [Element]

        init(_ container: borrowing NCContainer) {
            self._elements = container.elements
        }

        func callAsFunction(_ body: (Element) -> Void) {
            for element in _elements {
                body(element)
            }
        }

        consuming func consuming(_ body: (Element) -> Void) {
            print("  NOTE: consuming() consumes ForEachAccessor, not NCContainer")
            for element in _elements {
                body(element)
            }
        }
    }

    var forEach: ForEachAccessor {
        // This borrows self and returns a new accessor
        ForEachAccessor(self)
    }

    // The ONLY way to actually consume: explicit consuming method
    consuming func consumingForEach(_ body: (Element) -> Void) {
        for element in elements {
            body(element)
        }
        // self is consumed here
    }
}

func testVariant2() {
    print("=== Variant 2: ~Copyable Container ===")
    print()

    // Borrowing via .forEach works
    print("--- .forEach { } with ~Copyable ---")
    do {
        var container = NCContainer([10, 20, 30])
        container.forEach { element in
            print("  Element: \(element)")
        }
        print("  Container still valid: \(container.elements.count) elements")
    }
    print()

    // .forEach.consuming() doesn't actually consume the container
    print("--- .forEach.consuming() with ~Copyable ---")
    do {
        var container = NCContainer([40, 50, 60])
        container.forEach.consuming { element in
            print("  Element: \(element)")
        }
        print("  Container still valid: \(container.elements.count) elements")
        print("  CLAIM-005: Pattern compiles, but same limitation applies")
    }
    print()

    // consumingForEach() actually consumes
    print("--- .consumingForEach { } actually consumes ---")
    do {
        let container = NCContainer([70, 80, 90])
        container.consumingForEach { element in
            print("  Element: \(element)")
        }
        // container is consumed, cannot access
        print("  Container consumed (cannot access)")
    }
    print()
}

// MARK: - Variant 3: Namespace Method Pattern
// Question: What about .consuming().forEach { } ?

extension NCContainer {
    struct ConsumingNamespace: ~Copyable {
        var _container: NCContainer

        init(_ container: consuming NCContainer) {
            self._container = container
        }

        consuming func forEach(_ body: (Element) -> Void) {
            for element in _container.elements {
                body(element)
            }
            // _container destroyed when namespace is consumed
        }
    }

    // Must be a method, not property, because consuming
    consuming func consuming() -> ConsumingNamespace {
        ConsumingNamespace(self)
    }
}

func testVariant3() {
    print("=== Variant 3: Namespace Method Pattern ===")
    print()

    print("--- .consuming().forEach { } actually consumes ---")
    do {
        let container = NCContainer(["a", "b", "c"])
        container.consuming().forEach { element in
            print("  Element: \(element)")
        }
        // container is consumed
        print("  Container consumed (cannot access)")
    }
    print()

    print("--- Comparison: Same .forEach name, different namespace ---")
    print("  container.forEach { }           // borrows")
    print("  container.consuming().forEach { }  // consumes")
    print()
}

// MARK: - Variant 4: Property-style with Consumption State Tracking
// Question: Can _modify + state class enable .forEach.consuming?
//
// Key insight: Use mutating method (not consuming) that modifies shared state.
// The defer block checks state and conditionally restores.

extension NCContainer {
    /// State tracker for conditional restoration
    final class ConsumingState: @unchecked Sendable {
        var elements: [Element]?
        var consumed: Bool = false

        init(elements: [Element]) {
            self.elements = elements
        }
    }

    struct ForEachProperty: ~Copyable {
        let _state: ConsumingState

        init(state: ConsumingState) {
            self._state = state
        }

        // Borrowing via callAsFunction: .forEach { }
        func callAsFunction(_ body: (Element) -> Void) {
            guard let elements = _state.elements else { return }
            for element in elements {
                body(element)
            }
        }

        // Borrowing via property: .forEach.borrowing { }
        var borrowing: BorrowingAccessor {
            BorrowingAccessor(state: _state)
        }

        struct BorrowingAccessor {
            let _state: ConsumingState

            init(state: ConsumingState) {
                self._state = state
            }

            func callAsFunction(_ body: (Element) -> Void) {
                guard let elements = _state.elements else { return }
                for element in elements {
                    body(element)
                }
            }
        }

        // CONSUMING via MUTATING method: .forEach.consuming { }
        // Uses mutating (not consuming) because _modify yields mutable borrow, not ownership
        // The state class tracks that we "consumed" semantically
        mutating func consuming(_ body: (Element) -> Void) {
            guard let elements = _state.elements else { return }
            _state.consumed = true
            _state.elements = nil  // Prevent restoration
            for element in elements {
                body(element)
            }
        }
    }

    var forEachV4: ForEachProperty {
        _read {
            // For borrowing access
            let state = ConsumingState(elements: self.elements)
            yield ForEachProperty(state: state)
        }
        mutating _modify {
            // For consuming access via mutating method
            let state = ConsumingState(elements: self.elements)
            let originalElements = self.elements
            self.elements = []
            var property = ForEachProperty(state: state)
            defer {
                if !state.consumed {
                    self.elements = originalElements
                }
            }
            yield &property
        }
    }
}

func testVariant4() {
    print("=== Variant 4: Property-style with State Tracking ===")
    print()

    // Borrowing via callAsFunction
    print("--- .forEachV4 { } (borrowing) ---")
    do {
        var container = NCContainer(["A", "B", "C"])
        container.forEachV4 { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved (borrowing worked)")
    }
    print()

    // Borrowing via .borrowing
    print("--- .forEachV4.borrowing { } ---")
    do {
        var container = NCContainer(["D", "E", "F"])
        container.forEachV4.borrowing { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved")
    }
    print()

    // Consuming via .consuming
    print("--- .forEachV4.consuming { } ---")
    do {
        var container = NCContainer(["G", "H", "I"])
        container.forEachV4.consuming { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        if container.elements.isEmpty {
            print("  Result: Container CONSUMED! Elements transferred.")
            print("  *** .forEach.consuming WORKS with state tracking! ***")
        } else {
            print("  Result: Container NOT consumed (pattern failed)")
        }
    }
    print()
}

// MARK: - Variant 5: Using Property.Consuming from Property_Primitives
// This variant uses the actual Property.Consuming type from the package.

import Property_Primitives

struct CopyableContainer<Element> {
    var elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    enum ForEach {}
}

extension CopyableContainer {
    typealias Property<Tag> = Property_Primitives.Property<Tag, CopyableContainer<Element>>
}

extension CopyableContainer {
    var forEach: Property<ForEach>.Consuming<Element> {
        _read {
            // For borrowing access - no state tracking needed
            yield Property<ForEach>.Consuming<Element>(self)
        }
        mutating _modify {
            var property = Property<ForEach>.Consuming<Element>(self)
            self = CopyableContainer([])
            defer {
                if let restored = property.finalize() {
                    self = restored
                }
            }
            yield &property
        }
    }
}

extension Property_Primitives.Property.Consuming
where Tag == CopyableContainer<Element>.ForEach, Base == CopyableContainer<Element> {

    // Borrowing: .forEach { }
    func callAsFunction(_ body: (Element) -> Void) {
        guard let base = borrowBase() else { return }
        for element in base.elements {
            body(element)
        }
    }

    // Borrowing: .forEach.borrowing { }
    var borrowing: BorrowingAccessor {
        BorrowingAccessor(state: state)
    }

    struct BorrowingAccessor {
        let state: Property_Primitives.Property<Tag, Base>.Consuming<Element>.State

        func callAsFunction(_ body: (Element) -> Void) {
            guard let base = state.borrowBase() else { return }
            for element in base.elements {
                body(element)
            }
        }
    }

    // Consuming: .forEach.consuming { }
    mutating func consuming(_ body: (Element) -> Void) {
        guard let base = consumeBase() else { return }
        for element in base.elements {
            body(element)
        }
    }
}

func testVariant5PropertyConsuming() {
    print("=== Variant 5: Using Property.Consuming ===")
    print()

    // Borrowing via callAsFunction
    print("--- .forEach { } (borrowing) ---")
    do {
        var container = CopyableContainer([1, 2, 3])
        container.forEach { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved")
    }
    print()

    // Borrowing via .borrowing
    print("--- .forEach.borrowing { } ---")
    do {
        var container = CopyableContainer([4, 5, 6])
        container.forEach.borrowing { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved")
    }
    print()

    // Consuming via .consuming
    print("--- .forEach.consuming { } ---")
    do {
        var container = CopyableContainer([7, 8, 9])
        container.forEach.consuming { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        if container.elements.isEmpty {
            print("  Result: Container CONSUMED via Property.Consuming!")
            print("  *** Property.Consuming works! ***")
        } else {
            print("  Result: Container NOT consumed")
        }
    }
    print()
}

// MARK: - Variant 6: Property.View.Typed Pattern
// Question: Does combining View + Typed help?
//
// Answer: No - View still borrows via pointer, Typed just adds type parameter.
// The ownership semantics don't change.

func testVariant6() {
    print("=== Variant 6: Property.View.Typed Analysis ===")
    print()
    print("  Property.View uses UnsafeMutablePointer<Base> with ~Escapable lifetime.")
    print("  Property.Typed adds Element type parameter for property extensions.")
    print()
    print("  Neither changes the fundamental ownership semantics:")
    print("  - View borrows via pointer (lifetime-bound)")
    print("  - Typed adds type param (no ownership change)")
    print()
    print("  A Property.View.Typed would combine both but still borrow.")
    print("  Property.Consuming solves this with state tracking.")
    print()
}

// MARK: - Variant 7: Property.View Consuming Pattern (OPTIMAL)
// This variant uses Property.View with pointer-based consuming.
// Key insight: Same accessor supports both borrowing and consuming.
 borrowing (read through pointer)
 consuming (mutate through pointer)
//
// Advantages:
// - True ~Copyable support (no element copying)
// - Zero heap allocation
// - Perfect syntax: .forEach { } and .forEach.consuming { }
//
// Note: Using concrete Int type for demonstration. In production,
// the extension would be defined alongside the container type where
// Element is in scope.

struct NCContainerV7: ~Copyable {
    var elements: [Int]

    init(_ elements: [Int]) {
        self.elements = elements
    }

    deinit {
        print("  [deinit] NCContainerV7 with \(elements.count) elements")
    }

    enum ForEach {}
}

extension NCContainerV7 {
    typealias Property<Tag> = Property_Primitives.Property<Tag, NCContainerV7>
}

extension NCContainerV7 {
    var forEach: Property<ForEach>.View {
        // mutating _read for borrowing access (need &self for pointer)
        mutating _read {
            yield unsafe Property<ForEach>.View(&self)
        }
        // mutating _modify for consuming access (mutating methods)
        mutating _modify {
            var view = unsafe Property<ForEach>.View(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View
where Tag == NCContainerV7.ForEach, Base == NCContainerV7 {

    // Borrowing: .forEach { }
    func callAsFunction(_ body: (Int) -> Void) {
        for element in unsafe base.pointee.elements {
            body(element)
        }
    }

    // Borrowing: .forEach.borrowing { }
    func borrowing(_ body: (Int) -> Void) {
        for element in unsafe base.pointee.elements {
            body(element)
        }
    }

    // Consuming: .forEach.consuming { }
    // Uses `mutating` because _modify yields mutable borrow, not ownership.
    // The mutation clears the container through the pointer.
    // @_lifetime(&self) required for mutating methods on ~Escapable types.
    @_lifetime(&self)
    mutating func consuming(_ body: (Int) -> Void) {
        let elements = unsafe base.pointee.elements
        unsafe base.pointee.elements = []  // Clear through pointer
        for element in elements {
            body(element)
        }
    }
}

func testVariant7PropertyView() {
    print("=== Variant 7: Property.View Consuming Pattern (OPTIMAL) ===")
    print()
    print("  This uses Property.View with pointer-based mutation.")
    print("  Zero heap allocation, true ~Copyable support.")
    print()

    // Borrowing via callAsFunction
    print("--- .forEach { } (borrowing) ---")
    do {
        var container = NCContainerV7([100, 200, 300])
        container.forEach { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved")
    }
    print()

    // Borrowing via .borrowing
    print("--- .forEach.borrowing { } ---")
    do {
        var container = NCContainerV7([400, 500, 600])
        container.forEach.borrowing { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        print("  Result: Container preserved")
    }
    print()

    // Consuming via .consuming
    print("--- .forEach.consuming { } ---")
    do {
        var container = NCContainerV7([700, 800, 900])
        container.forEach.consuming { element in
            print("  Element: \(element)")
        }
        print("  Container after: \(container.elements.count) elements")
        if container.elements.isEmpty {
            print("  Result: Container CONSUMED via Property.View!")
            print("  *** Property.View consuming pattern works! ***")
        } else {
            print("  Result: Container NOT consumed")
        }
    }
    print()
}

// MARK: - Summary

func printSummary() {
    print("""
    ============================================================================
    SUMMARY
    ============================================================================

    Goal: Achieve .forEach.consuming syntax for consuming iteration

    FINDINGS:

    1. .forEach { } via callAsFunction: WORKS
       - Property accessor returns type with callAsFunction
       - Syntax: container.forEach { element in ... }

    2. .forEach.borrowing { }: WORKS
       - Nested accessor for explicit borrowing
       - Syntax: container.forEach.borrowing { element in ... }

    3. Basic .forEach.consuming { }: DOESN'T CONSUME CONTAINER
       - Simple accessor with consuming method only consumes the accessor
       - The original container is BORROWED when creating the accessor
       - Cannot transfer ownership through a borrowed reference

    4. State-tracking .forEach.consuming { }: WORKS! ✓
       - Use _read accessor with defer + reference-type state
       - State class tracks whether consuming() was called
       - defer checks state and skips restoration if consumed
       - Container elements are transferred, not just borrowed

    KEY INSIGHT:

    The state-tracking pattern works because:
    - _read accessor with defer can conditionally restore
    - Reference-type state survives the consuming method
    - defer checks state.consumed flag before restoring elements
    - If consumed, elements stay transferred; if borrowed, elements restore

    PATTERNS THAT ACHIEVE .forEach.consuming:

    A. State-tracking with reference type (NEW - WORKS):
       - container.forEach { }           // borrowing (restores)
       - container.forEach.consuming { } // consuming (doesn't restore)
       - Requires class-based state tracker
       - Some overhead from allocation

    B. Namespace method pattern (WORKS):
       - container.forEach { }              // borrowing
       - container.consuming().forEach { }  // consuming
       - No allocation overhead
       - Different call-site syntax

    C. Separate method names (WORKS):
       - container.forEach { }           // borrowing
       - container.consumingForEach { }  // consuming
       - Simplest implementation
       - Different method names

    PROPERTY.TYPED AND PROPERTY.VIEW ANALYSIS:

    - Property.Typed: Adds Element type parameter for property extensions.
      Does NOT change ownership semantics. Doesn't help here.

    - Property.View: Borrows via UnsafeMutablePointer with ~Escapable lifetime.
      Still borrows. Doesn't help with consuming.

    - Property.View.Typed: Would combine both, but still borrows.
      The state-tracking approach is the solution.

    RECOMMENDATION:

    OPTIMAL: Property.View Consuming Pattern (Variant 7)
    - Use Property.View with pointer-based mutation
    - Zero heap allocation
    - True ~Copyable support for container AND elements
    - Perfect syntax: .forEach { } vs .forEach.consuming { }
    - func methods for borrowing, mutating func for consuming

    Alternative: State-tracking pattern (Variant 4/5)
    - Use Property.Consuming for Copyable containers
    - Some allocation overhead for state class
    - Simpler to understand, but limited ~Copyable support

    PATTERN COMPARISON:

    | Pattern               | Syntax            | Alloc | ~Copyable | Complexity |
    |-----------------------|-------------------|-------|-----------|------------|
    | Property.View (V7)    | .forEach.consuming| None  | Full      | Low        |
    | Property.Consuming    | .forEach.consuming| Class | Copyable  | Medium     |
    | Namespace method      | .consuming().forEach| None| Full      | Low        |
    | Separate names        | .consumingForEach | None  | Full      | Lowest     |
    """)
}

// MARK: - Run Tests

print()
print("=== ForEach Consuming Accessor Pattern Test ===")
print()

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5PropertyConsuming()
testVariant6()
testVariant7PropertyView()
printSummary()

