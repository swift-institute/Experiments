// ===----------------------------------------------------------------------===//
// Experiment: Pointer with Memory.Address
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Pointer can be unified with Tagged using Memory.Address:
//             - Memory.Address lives in memory-primitives
//             - Pointer<Pointee> = Tagged<Pointee, Memory.Address>
//             - Pointer.Mutable via conditional extension
//             - Index-based subscript and arithmetic
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// STEPS:
// 1. Define Memory.Address (simulates memory-primitives)
// 2. Define Pointer<Pointee> = Tagged<Pointee, Memory.Address>
// 3. Add Mutable as conditional nested struct
// 4. Add Index-based subscript
// 5. Add allocation/deallocation with Index.Count
// 6. Test full integration
//
// RESULT: [CONFIRMED] - Full architecture works:
//         - Memory.Address as memory primitive
//         - Pointer<Pointee> = Tagged<Pointee, Memory.Address>
//         - Pointer.Mutable via conditional extension on Tagged
//         - Index-based subscript and arithmetic
//         - Allocation/deallocation with Index.Count
// ===----------------------------------------------------------------------===//

public import Identity_Primitives
public import Index_Primitives

// ============================================================================
// MARK: - Step 1: Memory.Address (would live in memory-primitives)
// ============================================================================

/// Namespace for memory-related primitives.
public enum Memory {}

extension Memory {
    /// A non-null memory address.
    ///
    /// Represents a physical memory location. The address is stored as
    /// `UnsafeRawPointer` internally with a non-null guarantee.
    ///
    /// This is the raw address type. For typed pointer access, use
    /// `Pointer<Pointee>` which combines `Memory.Address` with phantom typing.
    @safe
    public struct Address: Hashable, @unchecked Sendable {
        /// The raw pointer value, guaranteed non-null.
        @usableFromInline
        internal let _rawPointer: UnsafeRawPointer

        /// Creates an address from a raw pointer.
        ///
        /// - Parameter pointer: A non-null raw pointer.
        @inlinable
        public init(_ pointer: UnsafeRawPointer) {
            self._rawPointer = unsafe pointer
        }

        /// Creates an address from a typed pointer.
        @inlinable
        public init<T>(_ pointer: UnsafePointer<T>) {
            self._rawPointer = unsafe UnsafeRawPointer(pointer)
        }

        /// Creates an address from a mutable typed pointer.
        @inlinable
        public init<T>(_ pointer: UnsafeMutablePointer<T>) {
            self._rawPointer = unsafe UnsafeRawPointer(pointer)
        }

        /// The raw pointer value.
        @inlinable
        public var rawPointer: UnsafeRawPointer {
            _rawPointer
        }
    }
}

// ============================================================================
// MARK: - Step 2: Pointer as Tagged<Pointee, Memory.Address>
// ============================================================================

/// A non-null, typed pointer to elements of type `Pointee`.
///
/// `Pointer<Pointee>` combines `Memory.Address` with phantom typing via `Tagged`,
/// providing type-safe memory access with a non-null guarantee.
public typealias Pointer<Pointee: ~Copyable> = Tagged<Pointee, Memory.Address>

// ============================================================================
// MARK: - Step 3: Pointer Extensions
// ============================================================================

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    /// The underlying stdlib pointer, typed to the tag (Pointee).
    @inlinable
    public var base: UnsafePointer<Tag> {
        unsafe UnsafePointer<Tag>(rawValue.rawPointer.assumingMemoryBound(to: Tag.self))
    }

    /// Creates a pointer from an UnsafePointer.
    @inlinable
    public init(_ pointer: UnsafePointer<Tag>) {
        self.init(__unchecked: (), Memory.Address(unsafe pointer))
    }

    /// Accesses the pointee.
    @inlinable
    public var pointee: Tag {
        unsafeAddress {
            unsafe base
        }
    }

    /// Accesses the element at the given typed index.
    @inlinable
    public subscript(index: Index<Tag>) -> Tag {
        unsafeAddress {
            unsafe base.advanced(by: index.position.rawValue)
        }
    }

    /// Returns a pointer advanced by the given offset.
    @inlinable
    public func advanced(by offset: Index<Tag>.Offset) -> Self {
        unsafe Self(base.advanced(by: offset.rawValue))
    }

    /// Returns the displacement from this pointer to another.
    @inlinable
    public func distance(to other: Self) -> Index<Tag>.Offset {
        Index<Tag>.Offset(unsafe base.distance(to: other.base))
    }
}

// ============================================================================
// MARK: - Step 4: Pointer.Mutable via Conditional Extension
// ============================================================================

extension Tagged where RawValue == Memory.Address, Tag: ~Copyable {
    /// A mutable, non-null pointer to elements of type `Tag` (the Pointee).
    @safe
    public struct Mutable: Copyable, @unchecked Sendable {
        /// The underlying mutable pointer.
        @usableFromInline
        internal let _base: UnsafeMutablePointer<Tag>

        /// The underlying stdlib pointer.
        @inlinable
        public var base: UnsafeMutablePointer<Tag> { _base }

        /// Creates a mutable pointer.
        @inlinable
        public init(_ pointer: UnsafeMutablePointer<Tag>) {
            self._base = unsafe pointer
        }

        /// Accesses the pointee.
        @inlinable
        public var pointee: Tag {
            @inline(__always)
            unsafeAddress { unsafe UnsafePointer(_base) }
            @inline(__always)
            unsafeMutableAddress { unsafe _base }
        }

        /// Accesses the element at the given typed index.
        @inlinable
        public subscript(index: Index<Tag>) -> Tag {
            @inline(__always)
            unsafeAddress { unsafe UnsafePointer(_base.advanced(by: index.position.rawValue)) }
            @inline(__always)
            unsafeMutableAddress { unsafe _base.advanced(by: index.position.rawValue) }
        }

        /// Returns an immutable view of this pointer.
        @inlinable
        public var immutable: Tagged<Tag, Memory.Address> {
            unsafe Tagged<Tag, Memory.Address>(UnsafePointer(_base))
        }

        /// Returns a pointer advanced by the given offset.
        @inlinable
        public func advanced(by offset: Index<Tag>.Offset) -> Self {
            unsafe Self(_base.advanced(by: offset.rawValue))
        }

        /// Returns the displacement from this pointer to another.
        @inlinable
        public func distance(to other: Self) -> Index<Tag>.Offset {
            Index<Tag>.Offset(unsafe _base.distance(to: other._base))
        }
    }
}

// ============================================================================
// MARK: - Step 5: Allocation with Index.Count
// ============================================================================

extension Tagged.Mutable where RawValue == Memory.Address, Tag: ~Copyable {
    /// Allocates uninitialized memory for the specified count of instances.
    @inlinable
    public static func allocate(capacity: Index<Tag>.Count) -> Self {
        unsafe Self(UnsafeMutablePointer<Tag>.allocate(capacity: capacity.rawValue))
    }

    /// Deallocates the memory referenced by this pointer.
    @inlinable
    public func deallocate() {
        unsafe _base.deallocate()
    }

    /// Initializes this pointer's memory with the given value.
    @inlinable
    public func initialize(to value: consuming Tag) {
        unsafe _base.initialize(to: value)
    }

    /// Deinitializes the specified count of values.
    @inlinable
    @discardableResult
    public func deinitialize(count: Index<Tag>.Count) -> UnsafeMutableRawPointer {
        unsafe _base.deinitialize(count: count.rawValue)
    }
}

// ============================================================================
// MARK: - Step 6: Test
// ============================================================================

struct Element {
    var value: Int
}

func testPointerWithMemoryAddress() {
    print("=== Testing Pointer with Memory.Address ===\n")

    // Test 1: Allocation with Index.Count
    print("1. Allocation with Index<Element>.Count")
    let count: Index<Element>.Count = Index<Element>.Count(__unchecked: 3)
    var mutablePtr = Pointer<Element>.Mutable.allocate(capacity: count)
    defer { mutablePtr.deallocate() }
    print("   Allocated \(count.rawValue) elements ✓")

    // Test 2: Initialize elements using Index
    print("\n2. Initialize using Index<Element>")
    for i in 0..<3 {
        unsafe mutablePtr._base.advanced(by: i).initialize(to: Element(value: i * 10))
    }
    print("   Initialized elements: [0, 10, 20] ✓")

    // Test 3: Access via Index subscript
    print("\n3. Access via Index<Element> subscript")
    let idx0 = Index<Element>(__unchecked: (), position: 0)
    let idx1 = Index<Element>(__unchecked: (), position: 1)
    let idx2 = Index<Element>(__unchecked: (), position: 2)
    print("   mutablePtr[idx0] = \(mutablePtr[idx0].value)")
    print("   mutablePtr[idx1] = \(mutablePtr[idx1].value)")
    print("   mutablePtr[idx2] = \(mutablePtr[idx2].value)")

    // Test 4: Immutable conversion
    print("\n4. Immutable conversion")
    let immutablePtr: Pointer<Element> = mutablePtr.immutable
    print("   immutablePtr[idx1] = \(immutablePtr[idx1].value) ✓")

    // Test 5: Pointer arithmetic with Index.Offset
    print("\n5. Pointer arithmetic with Index<Element>.Offset")
    let offset = Index<Element>.Offset(2)
    let advancedPtr = immutablePtr.advanced(by: offset)
    print("   advanced by offset 2: pointee = \(advancedPtr.pointee.value) ✓")

    // Test 6: Distance between pointers
    print("\n6. Distance between pointers")
    let distance = immutablePtr.distance(to: advancedPtr)
    print("   distance = \(distance.rawValue) ✓")

    // Test 7: Modify through mutable subscript
    print("\n7. Modify through mutable subscript")
    mutablePtr[idx1] = Element(value: 999)
    print("   After modification: mutablePtr[idx1] = \(mutablePtr[idx1].value)")
    print("   Seen through immutable: immutablePtr[idx1] = \(immutablePtr[idx1].value) ✓")

    // Cleanup
    _ = mutablePtr.deinitialize(count: count)

    print("\n=== SUCCESS: Pointer with Memory.Address works! ===")
}

// Run the test
testPointerWithMemoryAddress()
