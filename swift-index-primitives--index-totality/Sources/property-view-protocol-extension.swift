// ===----------------------------------------------------------------------===//
// Experiment: Property.View via Protocol Extension (Not Protocol Requirement)
// ===----------------------------------------------------------------------===//
//
// KEY INSIGHT: The Property.View is provided by PROTOCOL EXTENSION, not required.
//
// Pattern:
// 1. Protocol requires the primitive capability methods
// 2. Protocol EXTENSION provides var remove: Property<...>.View automatically
// 3. Property.View EXTENSION provides the fluent API (.remove.last())
//
// Conformers implement ONLY the primitive. They get Property.View for FREE.
//
// ===----------------------------------------------------------------------===//

public import Property_Primitives

// MARK: - Tag Type

public enum RemoveTag {}

// MARK: - Protocol with Primitive Requirements

/// Protocol requiring removal primitives.
/// Conformers implement ONLY these methods.
public protocol Removable {
    associatedtype Element

    /// Primitive: Remove and return last element, or nil if empty.
    mutating func removeLast() -> Element?

    /// Primitive: Remove all elements.
    mutating func removeAll()
}

// MARK: - Protocol Extension Provides Property.View Automatically

extension Removable {
    /// Provided automatically by protocol extension.
    /// Conformers get this for FREE - they don't implement it.
    public var remove: Property<RemoveTag, Self>.View {
        mutating _read {
            yield unsafe Property<RemoveTag, Self>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<RemoveTag, Self>.View(&self)
            yield &view
        }
    }
}

// MARK: - Property.View Extension Provides Fluent API

extension Property.View where Tag == RemoveTag, Base: Removable {

    /// Fluent API: `.remove.last()`
    @_lifetime(&self)
    @inlinable
    public mutating func last() -> Base.Element? {
        unsafe base.pointee.removeLast()
    }

    /// Fluent API: `.remove.all()`
    @_lifetime(&self)
    @inlinable
    public mutating func all() {
        unsafe base.pointee.removeAll()
    }
}

// MARK: - Test Conformer

/// Conformer implements ONLY the primitive methods.
/// Gets .remove property and .remove.last()/.remove.all() for FREE.
struct AutoTestArray<Element> {
    var storage: [Element] = []

    init(_ elements: [Element]) {
        self.storage = elements
    }

    var count: Int { storage.count }
}

extension AutoTestArray: Removable {
    // ONLY these two methods are required:

    mutating func removeLast() -> Element? {
        guard !storage.isEmpty else { return nil }
        return storage.removeLast()
    }

    mutating func removeAll() {
        storage.removeAll()
    }

    // The .remove property is provided by protocol extension - we don't write it!
}

// MARK: - Test

func testProtocolExtensionPattern() {
    print("=== Protocol Extension Pattern Test ===\n")

    var array = AutoTestArray([1, 2, 3, 4, 5])
    print("Initial: count = \(array.count)")

    // Using .remove.last() - provided automatically!
    if let last = array.remove.last() {
        print("array.remove.last(): \(last)")
    }

    if let last = array.remove.last() {
        print("array.remove.last(): \(last)")
    }

    print("After removes: count = \(array.count)")

    // Using .remove.all() - provided automatically!
    array.remove.all()
    print("After remove.all(): count = \(array.count)")

    print("\n=== Protocol Extension Pattern CONFIRMED ===")
}

// MARK: - Summary

/*
WHAT CONFORMERS IMPLEMENT:

    extension MyType: Removable {
        mutating func removeLast() -> Element? { ... }
        mutating func removeAll() { ... }
    }

WHAT CONFORMERS GET FOR FREE:

    myInstance.remove          // Property.View (from protocol extension)
    myInstance.remove.last()   // Fluent API (from Property.View extension)
    myInstance.remove.all()    // Fluent API (from Property.View extension)

THE PROTOCOL REQUIREMENT IS THE PRIMITIVE (removeLast, removeAll).
THE PROPERTY.VIEW IS PROVIDED AUTOMATICALLY BY PROTOCOL EXTENSION.

This is analogous to how Comparison.Protocol works:
- Protocol requires: < and ==
- Protocol extension provides: var compare: Property<...>.View
- Conformers get .compare.to(), .compare.isLess(than:), etc. for free
*/
