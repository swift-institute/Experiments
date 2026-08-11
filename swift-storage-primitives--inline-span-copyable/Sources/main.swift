// MARK: - Conditional Span for Copyable Elements
// Purpose: Test whether Storage.Inline can provide Span when Element: Copyable
// Hypothesis: InlineArray<capacity, Element> + repeating init enables dense Span access
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED - InlineArray<capacity, Element> enables Span for Copyable elements
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-01-29

// MARK: - Core Insight
//
// The current Storage.Inline design uses 64-byte slots to support ~Copyable elements.
// But for Copyable elements, we can use InlineArray<capacity, Element> directly!
//
// Key: InlineArray.init(repeating:) requires Copyable, but that's exactly our constraint.

// MARK: - Variant 1: Dense Storage for Copyable
// Uses InlineArray<capacity, Element> with a sentinel/default value

struct DenseInline<Element: Copyable, let capacity: Int> {
    var _storage: InlineArray<capacity, Element>
    var _count: Int

    init(defaultValue: Element) {
        _storage = InlineArray(repeating: defaultValue)
        _count = 0
    }

    mutating func push(_ element: Element) {
        precondition(_count < capacity, "Overflow")
        _storage[_count] = element
        _count += 1
    }

    mutating func pop() -> Element? {
        guard _count > 0 else { return nil }
        _count -= 1
        return _storage[_count]
    }

    mutating func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            let span = unsafe Span<Element>(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }

    mutating func withMutableSpan<R>(_ body: (inout MutableSpan<Element>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            var span = unsafe MutableSpan<Element>(_unsafeStart: UnsafeMutablePointer(mutating: ptr), count: _count)
            return body(&span)
        }
    }
}

// MARK: - Variant 2: Factory-based initialization (no default value)
// Uses Optional<Element> internally, provides non-optional Span

struct DenseInline2<Element: Copyable, let capacity: Int> {
    var _storage: InlineArray<capacity, Element?>
    var _count: Int

    init() {
        _storage = InlineArray(repeating: nil)
        _count = 0
    }

    mutating func push(_ element: Element) {
        precondition(_count < capacity, "Overflow")
        _storage[_count] = element
        _count += 1
    }

    mutating func pop() -> Element? {
        guard _count > 0 else { return nil }
        _count -= 1
        let element = _storage[_count]!
        _storage[_count] = nil
        return element
    }

    // Note: This provides Span<Element?>, not Span<Element>
    // Cannot safely provide Span<Element> because layout of Element? != Element
    mutating func withOptionalSpan<R>(_ body: (Span<Element?>) -> R) -> R {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: (Element?).self)
            let span = unsafe Span<Element?>(_unsafeStart: ptr, count: _count)
            return body(span)
        }
    }
}

// MARK: - Variant 3: The "real" solution - uninitialized memory for Copyable
// Key insight: For Copyable, we can use UnsafeMutableBufferPointer pattern

struct DenseInline3<Element: Copyable, let capacity: Int>: ~Copyable {
    // Use tuple storage sized for Element, not 64-byte slots
    // Problem: We need stride * capacity bytes, but stride is runtime
    //
    // This is the fundamental limitation:
    // - InlineArray requires compile-time capacity
    // - Stride is runtime for generic Element
    // - Cannot compute bytes = stride * capacity at compile time
    //
    // HOWEVER: For specific Element types, we CAN know the stride!
}

// MARK: - Variant 4: Macro-generated storage (future)
// A macro could generate the correctly-sized tuple for each Element type
// Example: @InlineStorage(Int, capacity: 8) would expand to correct tuple size

// MARK: - Test Execution

print("=== Variant 1: Dense with default value ===")
do {
    var storage = DenseInline<Int, 8>(defaultValue: 0)
    storage.push(1)
    storage.push(2)
    storage.push(3)

    storage.withSpan { span in
        print("Span<Int> count: \(span.count)")
        print("Elements: \(span[0]), \(span[1]), \(span[2])")
    }

    storage.withMutableSpan { span in
        span[1] = 42
    }

    storage.withSpan { span in
        print("After mutation: \(span[0]), \(span[1]), \(span[2])")
    }

    print("Result: CONFIRMED - Dense storage with Span works for Copyable")
    print("Tradeoff: Requires default value at initialization")
}

print("\n=== Variant 2: Optional-based ===")
do {
    var storage = DenseInline2<Int, 8>()
    storage.push(10)
    storage.push(20)
    storage.push(30)

    storage.withOptionalSpan { span in
        print("Span<Int?> count: \(span.count)")
        print("Elements: \(span[0]!), \(span[1]!), \(span[2]!)")
    }

    print("Result: CONFIRMED - Optional storage works but provides Span<T?> not Span<T>")
    print("Limitation: Layout of Optional<T> may differ from T (tag byte)")
}

print("\n=== Layout Analysis ===")
print("Int stride: \(MemoryLayout<Int>.stride)")
print("Int? stride: \(MemoryLayout<Int?>.stride)")
print("String stride: \(MemoryLayout<String>.stride)")
print("String? stride: \(MemoryLayout<String?>.stride)")

// Small struct
struct Point { var x: Double; var y: Double }
print("Point stride: \(MemoryLayout<Point>.stride)")
print("Point? stride: \(MemoryLayout<Point?>.stride)")

// MARK: - Results Summary
print("\n=== RESULTS SUMMARY ===")
print("""
For Copyable elements, we CAN provide Span access via:

1. **DenseInline with default value** (CONFIRMED)
   - InlineArray<capacity, Element> with repeating init
   - Requires Element to have a default/sentinel value
   - True dense packing, true Span<Element>

2. **Optional-based** (CONFIRMED but limited)
   - InlineArray<capacity, Element?> with repeating nil
   - No default value needed
   - Provides Span<Element?> not Span<Element>
   - Layout differs: Optional<T> has tag byte overhead

RECOMMENDATION FOR Storage.Inline:

Keep the current 64-byte slot design for ~Copyable support.
Add CONDITIONAL Span for Copyable via extension:

```swift
extension Storage.Inline where Element: Copyable {
    /// Span access for Copyable elements.
    ///
    /// - Note: Uses layout assumption that stride <= 64 bytes.
    /// - Warning: Only valid when elements are densely packed at slot boundaries.
    public mutating func withSpan<R>(_ body: (Span<Element>) -> R) -> R {
        // Cannot work! 64-byte slots != MemoryLayout<Element>.stride
    }
}
```

PROBLEM: Even with Copyable constraint, the 64-byte slot layout
doesn't match Element stride. Span STILL doesn't work.

ACTUAL SOLUTION:

For Span support, need a SEPARATE storage type:
- Storage.Inline.Dense<Element: Copyable, let capacity: Int>
- Uses InlineArray<capacity, Element> (not 64-byte slots)
- Provides true Span access
- Requires default value or factory initializer
""")
