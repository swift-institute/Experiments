// MARK: - Experiment: Comparable Shadowing
// Purpose: Test if declaring a top-level Comparable protocol shadows Swift.Comparable
// Hypothesis: A module declaring `public protocol Comparable` will shadow Swift.Comparable
//             for consumers, allowing ~Copyable support and custom APIs
//
// Toolchain: swift-6.2
// Date: 2026-01-22

/// Our custom Comparable protocol that supports ~Copyable types.
///
/// This is intentionally named `Comparable` to test if it shadows `Swift.Comparable`.
public protocol Comparable: ~Copyable, Equatable {
    /// Returns true if lhs is less than rhs.
    static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

// Provide default implementations for other comparison operators
extension Comparable where Self: ~Copyable {
    @inlinable
    public static func > (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        rhs < lhs
    }

    @inlinable
    public static func <= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(rhs < lhs)
    }

    @inlinable
    public static func >= (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs < rhs)
    }
}

// MARK: - Equatable for ~Copyable

/// Custom Equatable that supports ~Copyable types.
public protocol Equatable: ~Copyable {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

extension Equatable where Self: ~Copyable {
    @inlinable
    public static func != (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
        !(lhs == rhs)
    }
}

// MARK: - Bridge to Swift.Comparable

// Question: Can we make Swift.Comparable types automatically conform to our Comparable?
// This would be the "magic" the user is asking about.

// Attempt 1: Extension on Swift.Comparable
// This should make all Swift.Comparable types also conform to our Comparable
extension Swift.Comparable {
    // Note: Swift.Comparable already has < operator, so this should work
}

// But we need actual conformance declaration...
// This is where it gets tricky - can we declare retroactive conformance?
