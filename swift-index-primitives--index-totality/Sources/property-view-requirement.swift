// ===----------------------------------------------------------------------===//
// Experiment Discovery: Property.View as Protocol Requirement
// ===----------------------------------------------------------------------===//
//
// QUESTION: Can we require Property.View as the protocol requirement instead
// of methods like removeAll() and removeLast()?
//
// CURRENT PATTERN (Clearable + forEach.consuming):
//   - Protocol requires: mutating func removeAll()
//   - Property.View extension provides: .forEach.consuming { }
//   - The extension CALLS removeAll() internally
//
// DESIRED PATTERN:
//   - Protocol requires: the Property.View itself (?)
//   - No method requirement (?)
//
// ===----------------------------------------------------------------------===//

// MARK: - Analysis

/*
APPROACH 1: Protocol Requires Associated View Type

    protocol RemoveLast_v1: ~Copyable {
        associatedtype RemoveView: ~Copyable & ~Escapable
        var remove: RemoveView { mutating get }
    }

    Problem: How does RemoveView.last() actually remove?
    It needs SOME primitive operation to call.
    We've just moved the requirement from a method to a type.


APPROACH 2: Protocol Requires Specific Property.View

    // This won't compile - protocols can't specify compound type requirements
    protocol RemoveLast_v2: ~Copyable {
        var remove: Property<Collection.Remove, Self>.View { mutating get }
    }


APPROACH 3: Marker Protocol with Default Implementation

    protocol RemoveLast_v3: ~Copyable {}

    extension Property.View
    where Tag == Collection.Remove, Base: RemoveLast_v3 & ~Copyable {
        mutating func last() -> Base.Element? {
            // Problem: How do we actually remove?
            // We have no way to access internal state without a primitive
        }
    }


KEY INSIGHT:

The Property.View pattern provides ERGONOMIC SYNTAX:
    .forEach.consuming { }    instead of    for x in self { } ; removeAll()
    .remove.last()            instead of    removeLast()

But Property.View is a LENS - it provides access to functionality.
The functionality itself must exist somewhere.

The relationship is:
    PRIMITIVE (capability) --> PROPERTY.VIEW (ergonomics)

NOT:
    PROPERTY.VIEW --> PRIMITIVE  (doesn't make sense)

You can't have a view of functionality that doesn't exist.


APPROACH 4: Two-Protocol Pattern (THE SOLUTION)

Split into two protocols:
- Internal: _CollectionRemovePrimitives (has method requirements)
- Public: CollectionRemovable (has Property.View requirement)

The public protocol inherits from the internal one, but:
- The underscore prefix signals "implementation detail"
- Users implement the underscored methods
- Users USE the .remove.last() syntax

See property-view-protocol-test.swift for working implementation.


CONCLUSION:

YES, we can make Property.View the PUBLIC protocol requirement.

The TRICK is to use TWO protocols:
1. Internal: _CollectionRemovePrimitives (has method requirements)
2. Public: CollectionRemovable (has Property.View requirement)

The public API appears to have no method requirements!
Users implement underscore-prefixed methods but use clean syntax.
*/
