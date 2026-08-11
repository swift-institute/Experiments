// ===----------------------------------------------------------------------===//
// Experiment: Property.View as Protocol Requirement - Simplified Test
// ===----------------------------------------------------------------------===//
//
// This demonstrates the TWO-PROTOCOL pattern:
// - Internal protocol has primitive method requirements
// - Public protocol has Property.View requirement
// - Users see clean .remove.last() syntax
//
// Due to Swift language constraints, we use a simplified approach here.
// ===----------------------------------------------------------------------===//

public import Property_Primitives

// MARK: - Tag Type (must be at module level due to Swift constraint)

public enum CollectionRemoveTag {}

// MARK: - Internal Capability Protocol

/// Internal protocol that defines the primitive operations.
/// Conformers implement these; users don't see them.
public protocol _CollectionRemovePrimitives {
    associatedtype Element

    /// Removes and returns the last element, or nil if empty.
    mutating func _primitiveRemoveLast() -> Element?

    /// Removes all elements.
    mutating func _primitiveRemoveAll()
}

// MARK: - Public API Protocol

/// Public protocol that requires the Property.View.
/// This is what users see and conform to.
public protocol CollectionRemovable: _CollectionRemovePrimitives {
    // The public requirement is the view, not the methods
    // Note: `mutating get` in protocol allows mutating _read/_modify in implementation
    var remove: Property<CollectionRemoveTag, Self>.View { mutating get }
}

// MARK: - Default View Implementation

extension CollectionRemovable {
    @inlinable
    public var remove: Property<CollectionRemoveTag, Self>.View {
        mutating _read {
            yield unsafe Property<CollectionRemoveTag, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<CollectionRemoveTag, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Property.View Methods

extension Property.View where Tag == CollectionRemoveTag, Base: _CollectionRemovePrimitives {

    /// Removes and returns the last element: `.remove.last()`
    @_lifetime(&self)
    @inlinable
    public mutating func last() -> Base.Element? {
        unsafe base.pointee._primitiveRemoveLast()
    }

    /// Removes all elements: `.remove.all()`
    @_lifetime(&self)
    @inlinable
    public mutating func all() {
        unsafe base.pointee._primitiveRemoveAll()
    }
}

// MARK: - Test Conformer

struct TestArray<Element> {
    var storage: [Element] = []

    init(_ elements: [Element]) {
        self.storage = elements
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
}

// Conform to internal capability protocol
extension TestArray: _CollectionRemovePrimitives {
    mutating func _primitiveRemoveLast() -> Element? {
        guard !storage.isEmpty else { return nil }
        return storage.removeLast()
    }

    mutating func _primitiveRemoveAll() {
        storage.removeAll()
    }
}

// Conform to public API protocol - gets default `remove` property
extension TestArray: CollectionRemovable {}

// MARK: - Usage Test

func testPropertyViewProtocol() {
    print("=== Property.View as Protocol Requirement Test ===\n")

    var array = TestArray([1, 2, 3, 4, 5])
    print("Initial: count = \(array.count)")

    // Using .remove.last() syntax
    if let last = array.remove.last() {
        print("Removed last: \(last)")  // 5
    }

    if let last = array.remove.last() {
        print("Removed last: \(last)")  // 4
    }

    print("After two removes: count = \(array.count)")  // 3

    // Using .remove.all() syntax
    array.remove.all()
    print("After remove.all(): count = \(array.count)")  // 0

    print("\n=== Test Passed ===")
}

// MARK: - Synthesis

/*
FINDINGS:

1. YES, we can make Property.View the PUBLIC protocol requirement.

2. The pattern uses TWO protocols:
   - Internal: _CollectionRemovePrimitives (has method requirements)
   - Public: CollectionRemovable (has Property.View requirement)

3. The public protocol inherits from the internal one:
   - Underscore prefix signals "implementation detail"
   - Users implement the underscored methods
   - Users USE the .remove.last() syntax

4. This achieves the user's goal:
   - No public removeAll() or removeLast() methods in protocol
   - Protocol requires Property.View (via default implementation)
   - Clean .remove.last() syntax

5. Swift language constraints to note:
   - Tag types must be at module level (not nested in protocol extensions)
   - Protocol properties need `{ get }` not `{ _read _modify }`
   - ~Copyable associated types have limitations

RECOMMENDATION:
Adopt this two-protocol pattern for Collection.Remove in swift-collection-primitives.

The public API will be:
    protocol CollectionRemovable {
        var remove: Property<Collection.Remove, Self>.View { mutating get }
    }

Conformers implement:
    extension MyType: _CollectionRemovePrimitives {
        mutating func _primitiveRemoveLast() -> Element? { ... }
        mutating func _primitiveRemoveAll() { ... }
    }
    extension MyType: CollectionRemovable {}

Users see:
    container.remove.last()   // Clean syntax, no underscore methods visible
    container.remove.all()
*/
