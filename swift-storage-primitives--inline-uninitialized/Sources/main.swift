// MARK: - Uninitialized Inline Storage Investigation
// Purpose: Test approaches to create truly uninitialized inline storage for ~Copyable
// Hypothesis: Swift 6.2 may provide ways to create uninitialized InlineArray
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED - No way to create uninitialized InlineArray for ~Copyable in Swift 6.2
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-29

// MARK: - The Core Problem
//
// InlineArray<capacity, Element>.init() requires Element: Copyable for repeating init.
// For ~Copyable, we need uninitialized storage.
//
// Approaches to test:
// 1. UnsafeRawBufferPointer allocated inline (not possible - heap only)
// 2. InlineArray with byte type, reinterpreted
// 3. ManagedBuffer for "small buffer optimization" pattern
// 4. Check Swift 6.2 for new InlineArray APIs

// MARK: - Variant 1: Byte-based InlineArray
// Hypothesis: Use InlineArray<bytes, UInt8> and reinterpret

struct ByteInline<let bytes: Int>: ~Copyable {
    var _storage: InlineArray<bytes, UInt8>

    init() {
        _storage = InlineArray(repeating: 0)
    }

    // Problem: bytes must be stride * capacity, but stride is runtime for generic Element
}

// Test: Can we use this for a known type?
struct IntInlineViaBytes: ~Copyable {
    // For 8 Ints: 8 * 8 = 64 bytes
    var _storage: InlineArray<64, UInt8>
    var _count: Int = 0

    init() {
        _storage = InlineArray(repeating: 0)
    }

    mutating func push(_ element: Int) {
        precondition(_count < 8, "Overflow")
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(base)
                .assumingMemoryBound(to: Int.self)
            unsafe (ptr + _count).initialize(to: element)
        }
        _count += 1
    }

    mutating func pop() -> Int? {
        guard _count > 0 else { return nil }
        _count -= 1
        return unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(base)
                .assumingMemoryBound(to: Int.self)
            return unsafe (ptr + _count).move()
        }
    }

    mutating func withSpan<R>(_ body: (Span<Int>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Int.self)
            let span = unsafe Span<Int>(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }
}

// MARK: - Variant 2: Generic over stride (computed from Element)
// The trick: Can we compute stride * capacity at COMPILE TIME?
//
// Answer: NO. MemoryLayout<Element>.stride is runtime even for concrete types.
// Swift doesn't have compile-time type introspection for layout.

// MARK: - Variant 3: Protocol witness table trick
// Could use a protocol with associated constant for stride
// But this doesn't help because the constant is still runtime-resolved

// MARK: - Variant 4: Check for InlineArray.init(unsafeUninitializedCapacity:)
// This API exists for Array but may not for InlineArray

// Checking what InlineArray has...
func checkInlineArrayAPIs() {
    // InlineArray<4, Int> APIs:
    // - init(repeating:) - requires Copyable
    // - subscript(index:) - get/set
    // - count (always returns capacity)
    //
    // No unsafeUninitializedCapacity initializer exists for InlineArray
    print("InlineArray does NOT have unsafeUninitializedCapacity initializer")
}

// MARK: - Variant 5: Could we add it via extension?
// No - we cannot add stored properties or special initializers via extension

// MARK: - Variant 6: What about withUnsafeTemporaryAllocation?
// This allocates on the stack but the allocation doesn't outlive the closure

func testTemporaryAllocation() {
    withUnsafeTemporaryAllocation(of: Int.self, capacity: 8) { buffer in
        // buffer is valid here
        buffer[0] = 1
        buffer[1] = 2
        print("Temporary allocation works: \(buffer[0]), \(buffer[1])")
    }
    // buffer is deallocated here - cannot return or store
    print("But cannot persist beyond closure scope")
}

// MARK: - Test Execution

print("=== Variant 1: Byte-based for known type ===")
do {
    var storage = IntInlineViaBytes()
    storage.push(1)
    storage.push(2)
    storage.push(3)

    storage.withSpan { span in
        print("Span<Int> count: \(span.count)")
        print("Elements: \(span[0]), \(span[1]), \(span[2])")
    }
    print("Result: CONFIRMED - Byte-based storage with Span works for specific types")
    print("Limitation: bytes parameter must be computed manually per Element type")
}

print("\n=== Variant 4: InlineArray API check ===")
checkInlineArrayAPIs()

print("\n=== Variant 6: Temporary allocation ===")
testTemporaryAllocation()

// MARK: - The REAL solution exploration
print("\n=== THE ACTUAL PATH FORWARD ===")
print("""
CONFIRMED CONSTRAINTS:
1. InlineArray requires Copyable for init() - no way around this
2. stride is runtime, cannot compute bytes at compile time for generic Element
3. No unsafeUninitializedCapacity initializer for InlineArray
4. withUnsafeTemporaryAllocation is scoped, cannot persist

VIABLE PATHS:

A. **Dual Storage Design** (recommended)
   - Storage.Inline<capacity>: 64-byte slots, ~Copyable support, no Span
   - Storage.Inline.Dense<capacity>: dense packing, Copyable only, has Span
   - User chooses based on their Element type

B. **Specialized Byte Storage**
   - Storage.Inline.Bytes<bytes>: raw byte storage
   - User computes bytes = MemoryLayout<Element>.stride * capacity
   - Unsafe but flexible

C. **Type-specific Storage**
   - Storage.Inline.Int8<capacity>
   - Storage.Inline.Int16<capacity>
   - etc.
   - Maximum safety, but requires per-type definitions

D. **Wait for Swift Evolution**
   - SE-XXXX: Uninitialized InlineArray
   - Would enable: InlineArray<capacity, Element>.init(uninitializedCapacity:)
   - This is the "right" solution but doesn't exist yet

RECOMMENDATION:
Option A - Dual Storage Design is the principled approach:
- Keep Storage.Inline for ~Copyable (current 64-byte slots)
- Add Storage.Inline.Dense for Copyable with Span support
- Document the tradeoff clearly
""")

// MARK: - Prototype: Storage.Inline.Dense

/// Dense inline storage for Copyable elements with Span support.
///
/// Unlike `Storage.Inline`, this type uses `InlineArray<capacity, Element>`
/// directly, providing true dense packing compatible with `Span`.
///
/// ## Requirements
/// - Element must be Copyable (required for InlineArray initialization)
/// - Must provide a default value for uninitialized slots
///
/// ## When to Use
/// - Use `Storage.Inline` for ~Copyable elements (no Span)
/// - Use `Storage.Inline.Dense` for Copyable elements with Span access
struct InlineDense<Element: Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline
    var _storage: InlineArray<capacity, Element>

    @usableFromInline
    var _count: Int

    /// Creates dense inline storage.
    ///
    /// - Parameter defaultValue: Value used to initialize unoccupied slots.
    @inlinable
    public init(defaultValue: Element) {
        _storage = InlineArray(repeating: defaultValue)
        _count = 0
    }

    /// The number of initialized elements.
    @inlinable
    public var count: Int { _count }

    /// Whether the storage is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the storage is full.
    @inlinable
    public var isFull: Bool { _count == capacity }

    /// Provides read-only span access to all initialized elements.
    @inlinable
    public mutating func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            let span = unsafe Span<Element>(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }

    /// Provides mutable span access to all initialized elements.
    @inlinable
    public mutating func withMutableSpan<R>(_ body: (inout MutableSpan<Element>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            var span = unsafe MutableSpan<Element>(_unsafeStart: ptr, count: _count)
            return body(&span)
        }
    }
}

print("\n=== Prototype: Storage.Inline.Dense ===")
do {
    var dense = InlineDense<Int, 8>(defaultValue: 0)
    dense._storage[0] = 100
    dense._storage[1] = 200
    dense._storage[2] = 300
    dense._count = 3

    dense.withSpan { span in
        print("Span count: \(span.count)")
        print("Elements: \(span[0]), \(span[1]), \(span[2])")
    }

    dense.withMutableSpan { span in
        span[1] = 999
    }

    dense.withSpan { span in
        print("After mutation: \(span[0]), \(span[1]), \(span[2])")
    }

    print("Result: CONFIRMED - Dense inline storage with Span works")
}
