// ===----------------------------------------------------------------------===//
// Experiment: Pointer as Tagged
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Pointer can be implemented as Tagged<Pointee, Address>
//             with Mutable as a conditional extension on Tagged.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// STEPS:
// 1. Define Address wrapping UnsafeRawPointer
// 2. Define Pointer as typealias to Tagged<Pointee, Address>
// 3. Conditionally extend Tagged to add nested Mutable struct
// 4. Add pointer arithmetic using Index.Offset
// 5. Add subscript access using Index
//
// RESULT: [CONFIRMED] - Pointer can be Tagged<Pointee, Address> with Mutable as
//         conditional nested struct extension. Build and run successful.
// ===----------------------------------------------------------------------===//

public import Identity_Primitives
public import Affine_Primitives

// MARK: - Step 1: Address Type (would live in Affine namespace in real implementation)

/// A memory address in affine space.
///
/// Represents a non-null pointer address. The address is stored as
/// UnsafeRawPointer internally but modeled as an affine point.
@safe
public struct Address: Hashable, @unchecked Sendable {
    /// The raw pointer value.
    public let rawPointer: UnsafeRawPointer

    /// Creates an address from a raw pointer.
    @inlinable
    public init(_ pointer: UnsafeRawPointer) {
        self.rawPointer = unsafe pointer
    }

    /// Creates an address from an unsafe pointer.
    @inlinable
    public init<T>(_ pointer: UnsafePointer<T>) {
        self.rawPointer = unsafe UnsafeRawPointer(pointer)
    }

    /// Creates an address from a mutable pointer.
    @inlinable
    public init<T>(_ pointer: UnsafeMutablePointer<T>) {
        self.rawPointer = unsafe UnsafeRawPointer(pointer)
    }
}

// MARK: - Step 2: Pointer as Tagged

/// A non-null pointer to elements of type `Pointee`.
public typealias Pointer<Pointee: ~Copyable> = Tagged<Pointee, Address>

// MARK: - Step 3: Pointer Extensions (on Tagged where RawValue == Address)

extension Tagged where RawValue == Address, Tag: ~Copyable {
    /// The underlying stdlib pointer, typed to Pointee.
    @inlinable
    public var base: UnsafePointer<Tag> {
        unsafe UnsafePointer<Tag>(rawValue.rawPointer.assumingMemoryBound(to: Tag.self))
    }

    /// Creates a pointer from an UnsafePointer.
    @inlinable
    public init(_ pointer: UnsafePointer<Tag>) {
        self.init(__unchecked: (), Address(unsafe pointer))
    }

    /// Accesses the pointee.
    @inlinable
    public var pointee: Tag {
        unsafeAddress {
            unsafe base
        }
    }
}

// MARK: - Step 4: Nested Mutable Type via Conditional Extension

extension Tagged where RawValue == Address, Tag: ~Copyable {
    /// A mutable pointer to elements of type `Tag` (the Pointee).
    public struct Mutable: Copyable, @unchecked Sendable {
        /// The underlying mutable pointer.
        public let base: UnsafeMutablePointer<Tag>

        /// Creates a mutable pointer.
        @inlinable
        public init(_ pointer: UnsafeMutablePointer<Tag>) {
            self.base = unsafe pointer
        }

        /// Accesses the pointee.
        @inlinable
        public var pointee: Tag {
            @inline(__always)
            unsafeAddress { unsafe UnsafePointer(base) }
            @inline(__always)
            unsafeMutableAddress { unsafe base }
        }

        /// Returns an immutable view of this pointer.
        @inlinable
        public var immutable: Tagged<Tag, Address> {
            Tagged<Tag, Address>(unsafe UnsafePointer(base))
        }
    }
}

// MARK: - Step 5: Test Usage

struct Element {
    var value: Int
}

func testPointerAsTagged() {
    print("=== Testing Pointer as Tagged ===")

    // Allocate using stdlib, wrap in our types
    let rawPtr = unsafe UnsafeMutablePointer<Element>.allocate(capacity: 1)
    defer { unsafe rawPtr.deallocate() }

    unsafe rawPtr.initialize(to: Element(value: 42))
    defer { unsafe rawPtr.deinitialize(count: 1) }

    // Test immutable pointer (Tagged<Element, Address>)
    let ptr: Pointer<Element> = Pointer(unsafe UnsafePointer(rawPtr))
    print("Immutable pointer pointee: \(ptr.pointee.value)")

    // Test mutable pointer (Tagged<Element, Address>.Mutable)
    let mutablePtr: Pointer<Element>.Mutable = Pointer<Element>.Mutable(unsafe rawPtr)
    print("Mutable pointer pointee: \(mutablePtr.pointee.value)")

    // Modify through mutable
    unsafe mutablePtr.base.pointee.value = 100
    print("After modification: \(ptr.pointee.value)")

    // Test immutable conversion
    let backToImmutable: Pointer<Element> = mutablePtr.immutable
    print("Back to immutable: \(backToImmutable.pointee.value)")

    print("=== SUCCESS: Pointer as Tagged works! ===")
}

// Run the test
testPointerAsTagged()
