// MARK: - ForEach Convenience Discovery (Custom ~Copyable Protocols)
// Purpose: Explore using custom Sequence/Collection protocols that support ~Copyable
//
// Architecture:
// - sequence-primitives provides Sequence.Protocol (supports ~Copyable)
// - collection-primitives provides Collection.Protocol (supports ~Copyable)
// - These packages depend on property-primitives
// - forEach conveniences live in sequence-primitives/collection-primitives
//
// This experiment simulates what sequence-primitives would provide.
//
// Toolchain: Apple Swift version 6.2.3
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// Date: 2026-01-22
//
// ============================================================================
// FINDINGS SUMMARY
// ============================================================================
//
// [FINDING-1] Stdlib Sequence/Collection require Copyable - cannot use for ~Copyable
// [FINDING-2] Custom Sequence.`Protocol`: ~Copyable enables generic forEach extensions
// [FINDING-3] Property.View extension where Base: SequenceProtocol works for ALL conformers
// [FINDING-4] Consumer boilerplate: ~10-12 lines (conformance + forEach property)
//
// ARCHITECTURE DECISION:
// - property-primitives: Property.View (pointer-based ~Copyable support)
// - sequence-primitives: Sequence.`Protocol`, Sequence.ForEach tag, borrowing extensions
// - collection-primitives: Collection.`Protocol`, consuming extensions
//
// RESULT: CONFIRMED - Custom ~Copyable protocols enable generic forEach conveniences
//
// ============================================================================

import Property_Primitives

// ============================================================================
// MARK: - Simulated sequence-primitives Types
// ============================================================================
// This simulates what sequence-primitives would provide.

/// Namespace for sequence-related types.
enum Sequence {
    // Tag for forEach functionality
    enum ForEach {}
}

/// Protocol for types that can be iterated, supporting ~Copyable.
/// This would live in sequence-primitives.
protocol SequenceProtocol: ~Copyable {
    associatedtype Element
    associatedtype Iterator: IteratorProtocol where Iterator.Element == Element

    /// Returns an iterator over the elements.
    borrowing func makeIterator() -> Iterator
}

// Convenience: Allow iterating with for-in
// (In reality, this might need compiler support or a different approach)

// ============================================================================
// MARK: - Simulated collection-primitives Types
// ============================================================================

/// Namespace for collection-related types.
enum Collection {
    enum ForEach {}
}

/// Protocol for collections that can be cleared, supporting ~Copyable.
/// This would live in collection-primitives.
protocol RangeReplaceableCollectionProtocol: SequenceProtocol & ~Copyable {
    /// Removes all elements from the collection.
    mutating func removeAll()
}

// ============================================================================
// MARK: - Property.View Extensions (would live in sequence-primitives)
// ============================================================================

/// Extension for ANY SequenceProtocol conformer - provides borrowing forEach.
extension Property.View
where Base: SequenceProtocol & ~Copyable, Tag == Sequence.ForEach {

    /// Borrowing iteration: .forEach { }
    func callAsFunction(_ body: (Base.Element) -> Void) {
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }

    /// Explicit borrowing: .forEach.borrowing { }
    func borrowing(_ body: (Base.Element) -> Void) {
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

/// Extension for RangeReplaceableCollectionProtocol - adds consuming.
extension Property.View
where Base: RangeReplaceableCollectionProtocol & ~Copyable, Tag == Sequence.ForEach {

    /// Consuming iteration: .forEach.consuming { }
    @_lifetime(&self)
    mutating func consuming(_ body: (Base.Element) -> Void) {
        var iterator = unsafe base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
        unsafe base.pointee.removeAll()
    }
}

// ============================================================================
// MARK: - Test Types (Consumer's ~Copyable Containers)
// ============================================================================

struct NCContainer<Element>: ~Copyable {
    var storage: [Element]

    init(_ elements: [Element]) {
        self.storage = elements
    }

    deinit {
        print("  [deinit] NCContainer with \(storage.count) elements")
    }
}

struct AnotherNC<Element>: ~Copyable {
    var items: [Element]

    init(_ items: [Element]) {
        self.items = items
    }

    deinit {
        print("  [deinit] AnotherNC with \(items.count) items")
    }
}

// ============================================================================
// MARK: - Consumer Conformances (MINIMAL BOILERPLATE!)
// ============================================================================

// NCContainer conforms to SequenceProtocol
extension NCContainer: SequenceProtocol {
    func makeIterator() -> Array<Element>.Iterator {
        storage.makeIterator()
    }
}

extension NCContainer: RangeReplaceableCollectionProtocol {
    mutating func removeAll() {
        storage.removeAll()
    }
}

// Add forEach property (~5 lines)
extension NCContainer {
    var forEach: Property<Sequence.ForEach, NCContainer>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, NCContainer>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, NCContainer>.View(&self)
            yield &view
        }
    }
}

// AnotherNC conforms to SequenceProtocol
extension AnotherNC: SequenceProtocol {
    func makeIterator() -> Array<Element>.Iterator {
        items.makeIterator()
    }
}

extension AnotherNC: RangeReplaceableCollectionProtocol {
    mutating func removeAll() {
        items.removeAll()
    }
}

// Add forEach property (~5 lines)
extension AnotherNC {
    var forEach: Property<Sequence.ForEach, AnotherNC>.View {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, AnotherNC>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, AnotherNC>.View(&self)
            yield &view
        }
    }
}

// ============================================================================
// MARK: - Tests
// ============================================================================

func testNCContainer() {
    print("=== NCContainer (~Copyable) with Custom Protocol ===")
    print()
    print("Conforms to: SequenceProtocol, RangeReplaceableCollectionProtocol")
    print("Boilerplate: ~10 lines (conformance + property)")
    print()

    print("--- NCContainer.forEach { } ---")
    do {
        var container = NCContainer([1, 2, 3])
        container.forEach { print("  Element: \($0)") }
        print("  After: \(container.storage.count) elements")
    }
    print()

    print("--- NCContainer.forEach.consuming { } ---")
    do {
        var container = NCContainer([10, 20, 30])
        container.forEach.consuming { print("  Element: \($0)") }
        print("  After: \(container.storage.count) elements")
        print("  Result: \(container.storage.isEmpty ? "CONSUMED!" : "NOT consumed")")
    }
    print()
}

func testAnotherNC() {
    print("=== AnotherNC (~Copyable) with Custom Protocol ===")
    print()
    print("Same pattern, different type - extensions work automatically!")
    print()

    print("--- AnotherNC.forEach { } ---")
    do {
        var container = AnotherNC(["a", "b", "c"])
        container.forEach { print("  Item: \($0)") }
        print("  After: \(container.items.count) items")
    }
    print()

    print("--- AnotherNC.forEach.consuming { } ---")
    do {
        var container = AnotherNC(["x", "y", "z"])
        container.forEach.consuming { print("  Item: \($0)") }
        print("  After: \(container.items.count) items")
        print("  Result: \(container.items.isEmpty ? "CONSUMED!" : "NOT consumed")")
    }
    print()
}

// ============================================================================
// MARK: - Summary
// ============================================================================

func printSummary() {
    print("""
    ============================================================================
    SUMMARY: Custom ~Copyable Protocol Approach
    ============================================================================

    ARCHITECTURE:

    ┌─────────────────────────────────────────────────────────────────────────┐
    │ property-primitives                                                      │
    │ - Property<Tag, Base>                                                   │
    │ - Property.View (pointer-based, ~Copyable support)                      │
    └─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ sequence-primitives                                                      │
    │ - Sequence.Protocol (supports ~Copyable)                                │
    │ - Sequence.ForEach tag                                                  │
    │ - Property.View extension for SequenceProtocol (borrowing)              │
    └─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ collection-primitives                                                    │
    │ - Collection.Protocol (supports ~Copyable)                              │
    │ - RangeReplaceableCollection.Protocol                                   │
    │ - Property.View extension for RRC (consuming)                           │
    └─────────────────────────────────────────────────────────────────────────┘

    CONSUMER BOILERPLATE:

    1. Conform to SequenceProtocol (~3 lines):
       ```swift
       extension MyType: SequenceProtocol {
           func makeIterator() -> Array<Element>.Iterator {
               storage.makeIterator()
           }
       }
       ```

    2. Conform to RangeReplaceableCollectionProtocol (~3 lines):
       ```swift
       extension MyType: RangeReplaceableCollectionProtocol {
           mutating func removeAll() { storage.removeAll() }
       }
       ```

    3. Add forEach property (~5 lines):
       ```swift
       var forEach: Property<Sequence.ForEach, MyType>.View {
           mutating _read { yield unsafe Property.View(&self) }
           mutating _modify {
               var view = unsafe Property.View(&self)
               yield &view
           }
       }
       ```

    TOTAL: ~10-12 lines per type (vs ~20+ without protocol conveniences)

    KEY BENEFITS:

    1. ~Copyable support via custom protocols
    2. Generic Property.View extensions serve ALL conforming types
    3. Consistent with your existing primitives architecture
    4. No stdlib protocol limitations

    PACKAGE RESPONSIBILITIES:

    | Package | Provides |
    |---------|----------|
    | property-primitives | Property.View, ForEach tag |
    | sequence-primitives | SequenceProtocol, borrowing extensions |
    | collection-primitives | CollectionProtocol, consuming extensions |
    | Consumer | Conformance + forEach property |
    """)
}

// ============================================================================
// MARK: - Run Tests
// ============================================================================

print()
print("=== ForEach Convenience Discovery (Custom ~Copyable Protocols) ===")
print()

testNCContainer()
testAnotherNC()
printSummary()
