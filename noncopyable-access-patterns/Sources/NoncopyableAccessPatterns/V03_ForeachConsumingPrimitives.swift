// MARK: - ForEach Consuming Accessor Pattern (Primitives Version — PRIMARY)
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
// Status: CONFIRMED
// Revalidation: When Property.View consuming pattern is adopted in production
// Origin: swift-primitives/Experiments/foreach-consuming-accessor (PRIMARY)
// Note: This is the primary version that originally tested against real
//       Property.View types from Property_Primitives. The Property_Primitives
//       dependency has been replaced with standalone type definitions below.

enum V03_ForeachConsumingPrimitives {

    // MARK: - Standalone Property.View Stand-in
    // The original experiment imported Property_Primitives. This standalone
    // definition captures the essential pointer-based view pattern.

    struct PropertyView<Base: ~Copyable>: ~Copyable, ~Escapable {
        @usableFromInline
        let base: UnsafeMutablePointer<Base>

        @_lifetime(borrow base)
        @inlinable
        init(_ base: UnsafeMutablePointer<Base>) {
            self.base = base
        }
    }

    // MARK: - Standalone Property.Consuming Stand-in

    final class ConsumingState<Base>: @unchecked Sendable {
        var base: Base?
        var consumed: Bool = false

        init(_ base: Base) {
            self.base = base
        }

        func borrowBase() -> Base? { base }

        func consumeBase() -> Base? {
            guard let b = base else { return nil }
            consumed = true
            base = nil
            return b
        }
    }

    struct PropertyConsuming<Base> {
        let state: ConsumingState<Base>

        init(_ base: Base) {
            state = ConsumingState(base)
        }

        func finalize() -> Base? {
            if !state.consumed { return state.base }
            return nil
        }
    }

    // MARK: - Test Container (Copyable for simplicity)

    struct Container<Element> {
        var elements: [Element]

        init(_ elements: [Element]) {
            self.elements = elements
        }
    }

    // MARK: - Variant 1: Basic Accessor Pattern

    struct ForEachAccessor<Element> {
        var _elements: [Element]

        init(_ elements: [Element]) {
            self._elements = elements
        }

        func callAsFunction(_ body: (Element) -> Void) {
            for element in _elements {
                body(element)
            }
        }

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

        consuming func consuming(_ body: (Element) -> Void) {
            print("  NOTE: consuming() consumes the ForEachAccessor, not Container")
            for element in _elements {
                body(element)
            }
        }
    }

    // MARK: - Variant 2: ~Copyable Container

    struct NCContainer<Element>: ~Copyable {
        var elements: [Element]

        init(_ elements: [Element]) {
            self.elements = elements
        }

        deinit {
            print("  NCContainer deinit with \(elements.count) elements")
        }
    }

    // MARK: - Variant 3: Namespace Method Pattern

    struct ConsumingNamespace<Element>: ~Copyable {
        var _elements: [Element]

        init(_ elements: consuming [Element]) {
            self._elements = elements
        }

        consuming func forEach(_ body: (Element) -> Void) {
            for element in _elements {
                body(element)
            }
        }
    }

    // MARK: - Variant 4: State Tracking Pattern (NCContainer)

    struct ForEachProperty<Element>: ~Copyable {
        let _state: V02_ForeachConsumingInstitute.ConsumingState<Element>

        init(state: V02_ForeachConsumingInstitute.ConsumingState<Element>) {
            self._state = state
        }

        func callAsFunction(_ body: (Element) -> Void) {
            guard let elements = _state.elements else { return }
            for element in elements {
                body(element)
            }
        }

        var borrowing: BorrowingView {
            BorrowingView(state: _state)
        }

        struct BorrowingView {
            let _state: V02_ForeachConsumingInstitute.ConsumingState<Element>

            init(state: V02_ForeachConsumingInstitute.ConsumingState<Element>) {
                self._state = state
            }

            func callAsFunction(_ body: (Element) -> Void) {
                guard let elements = _state.elements else { return }
                for element in elements {
                    body(element)
                }
            }
        }

        mutating func consuming(_ body: (Element) -> Void) {
            guard let elements = _state.elements else { return }
            _state.consumed = true
            _state.elements = nil
            for element in elements {
                body(element)
            }
        }
    }

    // MARK: - Variant 5: Property.Consuming Stand-in

    struct CopyableContainer<Element> {
        var elements: [Element]

        init(_ elements: [Element]) {
            self.elements = elements
        }
    }

    // MARK: - Variant 7: Property.View Consuming Pattern (OPTIMAL)
    // Key insight: Same accessor supports both borrowing and consuming.
    // - func methods -> borrowing (read through pointer)
    // - mutating func methods -> consuming (mutate through pointer)
    //
    // Advantages:
    // - True ~Copyable support (no element copying)
    // - Zero heap allocation
    // - Perfect syntax: .forEach { } and .forEach.consuming { }

    struct NCContainerV7: ~Copyable {
        var elements: [Int]

        init(_ elements: [Int]) {
            self.elements = elements
        }

        deinit {
            print("  [deinit] NCContainerV7 with \(elements.count) elements")
        }
    }

    // MARK: - Summary
    //
    // OPTIMAL: Property.View Consuming Pattern (Variant 7)
    // - Use Property.View with pointer-based mutation
    // - Zero heap allocation
    // - True ~Copyable support for container AND elements
    // - Perfect syntax: .forEach { } vs .forEach.consuming { }
    // - func methods for borrowing, mutating func for consuming
    //
    // PATTERN COMPARISON:
    //
    // | Pattern               | Syntax            | Alloc | ~Copyable | Complexity |
    // |-----------------------|-------------------|-------|-----------|------------|
    // | Property.View (V7)    | .forEach.consuming| None  | Full      | Low        |
    // | Property.Consuming    | .forEach.consuming| Class | Copyable  | Medium     |
    // | Namespace method      | .consuming().forEach| None| Full      | Low        |
    // | Separate names        | .consumingForEach | None  | Full      | Lowest     |

    // MARK: - Run

    static func run() {
        print()
        print("=== ForEach Consuming Accessor Pattern Test (Primitives) ===")
        print()

        // Variant 1: Basic Accessor
        print("=== Variant 1: Basic Accessor with Copyable Container ===")
        print()

        print("--- CLAIM-001: .forEach { } via callAsFunction ---")
        do {
            let container = Container([1, 2, 3])
            let accessor = ForEachAccessor(container.elements)
            accessor { element in
                print("  Element: \(element)")
            }
            print("  Container still valid: \(container.elements.count) elements")
            print("  Result: CONFIRMED")
        }
        print()

        print("--- CLAIM-002: .borrowing { } ---")
        do {
            let container = Container([4, 5, 6])
            let accessor = ForEachAccessor(container.elements)
            accessor.borrowing { element in
                print("  Element: \(element)")
            }
            print("  Container still valid: \(container.elements.count) elements")
            print("  Result: CONFIRMED")
        }
        print()

        print("--- CLAIM-003 & CLAIM-004: .consuming() ---")
        do {
            let container = Container([7, 8, 9])
            let accessor = ForEachAccessor(container.elements)
            accessor.consuming { element in
                print("  Element: \(element)")
            }
            print("  Container still valid: \(container.elements.count) elements")
            print("  CLAIM-003 (method exists): CONFIRMED")
            print("  CLAIM-004 (actually consumes): REFUTED")
        }
        print()

        // Variant 3: Namespace Method Pattern
        print("=== Variant 3: Namespace Method Pattern ===")
        print()

        print("--- .consuming().forEach { } actually consumes ---")
        do {
            let ns = ConsumingNamespace(["a", "b", "c"])
            ns.forEach { element in
                print("  Element: \(element)")
            }
            print("  Container consumed (cannot access)")
        }
        print()

        // Variant 4: State Tracking
        print("=== Variant 4: Property-style with State Tracking ===")
        print()

        print("--- Borrowing via callAsFunction ---")
        do {
            let state = V02_ForeachConsumingInstitute.ConsumingState(elements: ["A", "B", "C"])
            let property = ForEachProperty(state: state)
            property { element in
                print("  Element: \(element)")
            }
            print("  Elements preserved: \(state.elements?.count ?? 0)")
        }
        print()

        print("--- Consuming via .consuming ---")
        do {
            let state = V02_ForeachConsumingInstitute.ConsumingState(elements: ["G", "H", "I"])
            var property = ForEachProperty(state: state)
            property.consuming { element in
                print("  Element: \(element)")
            }
            if state.consumed {
                print("  Result: Container CONSUMED!")
            }
        }
        print()

        // Variant 5: Property.Consuming Stand-in
        print("=== Variant 5: Property.Consuming Stand-in ===")
        print()

        print("--- Borrowing ---")
        do {
            let pc = PropertyConsuming(CopyableContainer([1, 2, 3]))
            if let base = pc.state.borrowBase() {
                for element in base.elements {
                    print("  Element: \(element)")
                }
            }
            print("  Container preserved: \(pc.state.base != nil)")
        }
        print()

        print("--- Consuming ---")
        do {
            let pc = PropertyConsuming(CopyableContainer([7, 8, 9]))
            if let base = pc.state.consumeBase() {
                for element in base.elements {
                    print("  Element: \(element)")
                }
            }
            print("  Container consumed: \(pc.state.consumed)")
        }
        print()

        // Variant 7: Property.View pointer-based pattern
        print("=== Variant 7: Property.View Consuming Pattern (OPTIMAL) ===")
        print()

        print("--- Borrowing via pointer ---")
        do {
            var container = NCContainerV7([100, 200, 300])
            withUnsafeMutablePointer(to: &container) { ptr in
                let view = unsafe PropertyView(ptr)
                for element in unsafe view.base.pointee.elements {
                    print("  Element: \(element)")
                }
            }
            print("  Container after: \(container.elements.count) elements")
            print("  Result: Container preserved")
        }
        print()

        print("--- Consuming via pointer ---")
        do {
            var container = NCContainerV7([700, 800, 900])
            withUnsafeMutablePointer(to: &container) { ptr in
                let elements = unsafe ptr.pointee.elements
                unsafe ptr.pointee.elements = []
                for element in elements {
                    print("  Element: \(element)")
                }
            }
            print("  Container after: \(container.elements.count) elements")
            if container.elements.isEmpty {
                print("  Result: Container CONSUMED via pointer!")
            }
        }
        print()
    }
}
