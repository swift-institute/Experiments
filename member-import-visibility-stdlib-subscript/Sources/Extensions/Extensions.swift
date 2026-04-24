// Extensions — analogous to Ordinal_Primitives_Standard_Library_Integration
//
// Extends stdlib types (UnsafePointer, InlineArray) with subscript<O: P>(position:)

public import Core

// MARK: - UnsafePointer + P

extension UnsafePointer {
    @inlinable
    public subscript<O: P>(position: O) -> Pointee {
        get {
            unsafe self[position.rawValue]
        }
    }
}

// MARK: - UnsafeMutablePointer + P

extension UnsafeMutablePointer {
    @inlinable
    public subscript<O: P>(position: O) -> Pointee {
        get {
            unsafe self[position.rawValue]
        }
        nonmutating set {
            unsafe self[position.rawValue] = newValue
        }
    }
}
