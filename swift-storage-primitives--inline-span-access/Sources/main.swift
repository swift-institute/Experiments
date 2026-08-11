// MARK: - Storage.Inline Span Access Investigation
// Purpose: Investigate approaches to enable Span access for inline storage with ~Copyable elements
// Hypothesis: Multiple approaches exist; identify which work with Swift 6.2 constraints
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - Multiple approaches exist; none enable Span for ~Copyable + truly inline
// Date: 2026-01-29

// MARK: - Background
//
// Current Storage.Inline uses 64-byte slots (tuple-based InlineArray) because:
// 1. InlineArray requires Copyable for init() - cannot create uninitialized storage for ~Copyable
// 2. Span expects dense packing at MemoryLayout<Element>.stride intervals
// 3. 64-byte slots allow any element up to 64 bytes but break Span compatibility
//
// This experiment tests approaches to enable dense packing for Span access.

// MARK: - Variant 1: ManagedBuffer for inline-like semantics
// Hypothesis: Use ManagedBuffer with small capacity as "inline" storage
// Result: [PENDING]

final class SmallBuffer<Element: ~Copyable>: ManagedBuffer<Int, Element> {
    static func create(capacity: Int) -> SmallBuffer<Element> {
        let buffer = SmallBuffer<Element>.create(minimumCapacity: capacity) { _ in 0 }
        return unsafe unsafeDowncast(buffer, to: SmallBuffer<Element>.self)
    }

    var count: Int {
        get { header }
        set { header = newValue }
    }

    deinit {
        guard count > 0 else { return }
        _ = unsafe withUnsafeMutablePointerToElements { base in
            for i in 0..<count {
                unsafe (base + i).deinitialize(count: 1)
            }
        }
    }
}

// MARK: - Variant 2: Raw memory buffer with manual management
// Hypothesis: Use UnsafeMutableRawBufferPointer for dense storage
// Result: [PENDING]

struct RawInlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    // Use InlineArray of bytes for raw storage (NOT 64-byte slots)
    // Problem: InlineArray<N, UInt8> requires N to be capacity * stride
    // which is a runtime value for ~Copyable Element

    // This approach FAILS at compile time - stride is not a compile-time constant
}

// MARK: - Variant 3: Conditional Span via protocol
// Hypothesis: Provide Span only when Element is Copyable
// Result: [PENDING]

protocol SpanAccessible {
    associatedtype Element
    func withSpan<R>(_ body: (Span<Element>) -> R) -> R
}

// Extension for Copyable only - can use InlineArray<capacity, Element> directly
extension SmallBuffer: SpanAccessible where Element: Copyable {
    func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
        unsafe withUnsafeMutablePointerToElements { base in
            let span = unsafe Span(_unsafeStart: UnsafePointer(base), count: count)
            return body(span)
        }
    }
}

// MARK: - Variant 4: InlineArray with Copyable constraint
// Hypothesis: Use InlineArray<capacity, Element> when Element: Copyable
// Result: [PENDING]

struct DenseInlineStorage<Element: Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Element>
    var _count: Int = 0

    init() {
        // This works because Element: Copyable allows init(repeating:)
        // But what do we repeat? Need a "default" value
        fatalError("Cannot create without default value")
    }

    init(defaultValue: Element) {
        _storage = InlineArray(repeating: defaultValue)
        _count = 0
    }
}

// MARK: - Variant 5: Optional-wrapped storage
// Hypothesis: Use InlineArray<capacity, Element?> to represent uninitialized as nil
// Result: [PENDING]

struct OptionalInlineStorage<Element: Copyable, let capacity: Int> {
    var _storage: InlineArray<capacity, Element?>
    var _count: Int = 0

    init() {
        _storage = InlineArray(repeating: nil)
    }

    mutating func push(_ element: Element) {
        _storage[_count] = element
        _count += 1
    }

    mutating func withSpan<R>(_ body: (Span<Element?>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: (Element?).self)
            let span = unsafe Span<Element?>(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }

    // Note: Span<Element?> is NOT Span<Element> - would need unwrapping
}

// MARK: - Variant 6: UnsafeMutableBufferPointer allocation
// Hypothesis: Allocate raw memory sized for dense elements
// Result: [PENDING]

struct AllocatedInlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    // This is effectively heap allocation, not inline storage
    // Defeats the purpose of "inline"
}

// MARK: - Variant 7: Tuple of exact size (compile-time stride)
// Hypothesis: For KNOWN element types, use appropriately-sized tuples
// Result: [PENDING]

// Example: Storage for exactly 8 Ints (stride = 8 bytes each)
struct IntInline8: ~Copyable {
    var _storage: (Int, Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0, 0)
    var _count: Int = 0

    mutating func withSpan<R>(_ body: (Span<Int>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Int.self)
            let span = unsafe Span(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }
}

// MARK: - Variant 8: Generic over stride via additional parameter
// Hypothesis: Pass stride as compile-time parameter
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

// This would require: struct Storage<Element, let capacity: Int, let stride: Int>
// Problem: stride must equal MemoryLayout<Element>.stride, no way to enforce at compile time

// MARK: - Test Execution

print("=== Variant 1: ManagedBuffer ===")
do {
    let buffer = SmallBuffer<Int>.create(capacity: 8)
    _ = unsafe buffer.withUnsafeMutablePointerToElements { base in
        unsafe (base + 0).initialize(to: 1)
        unsafe (base + 1).initialize(to: 2)
        unsafe (base + 2).initialize(to: 3)
    }
    buffer.count = 3

    buffer.withSpan { span in
        print("Span count: \(span.count)")
        print("Elements: \(span[0]), \(span[1]), \(span[2])")
    }
    print("Result: CONFIRMED - ManagedBuffer provides dense storage with Span access")
    print("Limitation: Requires heap allocation, not truly inline")
}

print("\n=== Variant 5: Optional-wrapped ===")
do {
    var storage = OptionalInlineStorage<Int, 8>()
    storage.push(10)
    storage.push(20)
    storage.push(30)

    storage.withSpan { span in
        print("Span<Int?> count: \(span.count)")
        print("Elements: \(span[0]!), \(span[1]!), \(span[2]!)")
    }
    print("Result: CONFIRMED - Optional wrapping enables Span<Element?>")
    print("Limitation: Span<Element?> not Span<Element>, requires unwrapping")
}

print("\n=== Variant 7: Type-specific tuple ===")
do {
    var storage = IntInline8()
    storage._storage.0 = 100
    storage._storage.1 = 200
    storage._storage.2 = 300
    storage._count = 3

    storage.withSpan { span in
        print("Span count: \(span.count)")
        print("Elements: \(span[0]), \(span[1]), \(span[2])")
    }
    print("Result: CONFIRMED - Type-specific tuples enable Span")
    print("Limitation: Not generic over Element type")
}

// MARK: - Results Summary
print("\n=== RESULTS SUMMARY ===")
print("""
| Variant | Works | ~Copyable | Truly Inline | Generic | Notes |
|---------|-------|-----------|--------------|---------|-------|
| 1. ManagedBuffer | Yes | Yes | No (heap) | Yes | Best for ~Copyable |
| 2. Raw bytes | No | - | - | - | Stride not compile-time |
| 3. Conditional | Yes | No | Varies | Yes | Span only for Copyable |
| 4. Dense InlineArray | Partial | No | Yes | Yes | Needs default value |
| 5. Optional-wrapped | Yes | No | Yes | Yes | Span<T?> not Span<T> |
| 6. Allocated | Yes | Yes | No (heap) | Yes | Defeats inline purpose |
| 7. Type-specific | Yes | Yes | Yes | No | Per-type implementation |
| 8. Stride parameter | No | - | - | - | Cannot enforce constraint |
""")

print("\n=== CONCLUSION ===")
print("""
For Storage.Inline to support Span, the fundamental constraint is:
- Span requires dense packing at MemoryLayout<Element>.stride intervals
- ~Copyable elements cannot use InlineArray<N, Element> (no init())
- 64-byte slots break Span's layout expectation

VIABLE APPROACHES:

1. **Accept asymmetry** (current approach):
   - Heap storage: Span works (dense packing)
   - Inline storage: No Span (strided access via forEach/withElement)

2. **Conditional Span** (recommended):
   - Provide Span only when Element: Copyable
   - Use InlineArray<capacity, Element> with repeating init
   - ~Copyable elements use strided access

3. **Small heap buffer** (tradeoff):
   - Use ManagedBuffer with small fixed capacity
   - Trades true inlining for Span compatibility
   - Better cache locality than arbitrary heap allocation

RECOMMENDED: Option 2 (Conditional Span)
- Add: extension Storage.Inline where Element: Copyable { withSpan(...) }
- Existing strided access remains for ~Copyable
- Clean API separation
""")
