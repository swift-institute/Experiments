// SUPERSEDED (2026-06-23): Memory.Contiguous was dissolved — its read-capability
//   protocol is now Span.Protocol (the renamed/relocated Memory.Contiguous.Protocol).
//   Storage.Heap / Storage.Inline conform to Span.Protocol today; the conformance
//   feasibility confirmed below is preserved as the historical record. See
//   swift-institute/Research/memory-contiguous-dissolution.md.
//
// MARK: - Memory.Contiguous.Protocol Conformance for Storage Types
// Purpose: Verify that Storage.Heap and Storage.Inline can conform to
//   Memory.Contiguous.Protocol using Swift 6.2 @lifetime annotations.
//
// Hypothesis: Property-based span access is possible using @lifetime(borrow self)
//   and @lifetime(&self) annotations with _overrideLifetime.
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED - Storage.Inline can conform; Storage.Heap partially (span only)
//   Build Succeeded, all variants execute correctly
// Date: 2026-02-05

// ============================================================================
// MARK: - Replicate Memory.Contiguous.Protocol
// ============================================================================

enum Memory {
    enum Contiguous {}
}

extension Memory.Contiguous {
    protocol `Protocol`: ~Copyable {
        associatedtype Element

        var span: Span<Element> { get }
        var mutableSpan: MutableSpan<Element> { mutating get }

        func withUnsafeBufferPointer<R, E: Swift.Error>(
            _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
        ) throws(E) -> R

        mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
            _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
        ) throws(E) -> R
    }
}

// ============================================================================
// MARK: - Variant 1: Heap Storage with @lifetime + _overrideLifetime
// Hypothesis: Can use _overrideLifetime to establish lifetime dependency
// Result: [PENDING]
// ============================================================================

final class HeapStorage<Element: ~Copyable>: ManagedBuffer<Int, Element> {
    static func create(capacity: Int) -> HeapStorage<Element> {
        let buffer = HeapStorage<Element>.create(minimumCapacity: capacity) { _ in 0 }
        return unsafe unsafeDowncast(buffer, to: HeapStorage<Element>.self)
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

extension HeapStorage where Element: Copyable {
    // Property-based span using @lifetime + _overrideLifetime
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            // Get pointer via closure, create span, then override lifetime
            let (ptr, cnt) = unsafe withUnsafeMutablePointerToElements { base in
                (UnsafePointer(base), count)
            }
            let span = unsafe Span(_unsafeStart: ptr, count: cnt)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    // Classes cannot have mutating getters, so mutableSpan must be closure-based
    func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            var span = unsafe MutableSpan(_unsafeStart: base, count: count)
            return try body(&span)
        }
    }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let buffer = unsafe UnsafeBufferPointer(start: base, count: count)
            return try unsafe body(buffer)
        }
    }

    func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafeMutablePointerToElements { base throws(E) in
            let buffer = unsafe UnsafeMutableBufferPointer(start: base, count: count)
            return try unsafe body(buffer)
        }
    }
}

func testHeapStorage() {
    print("=== Variant 1: HeapStorage with _overrideLifetime ===")
    print()

    let storage = HeapStorage<Int>.create(capacity: 8)
    _ = unsafe storage.withUnsafeMutablePointerToElements { base in
        for i in 0..<4 {
            unsafe (base + i).initialize(to: (i + 1) * 10)
        }
    }
    storage.count = 4

    // Test property-based span access (scoped)
    print("span property test:")
    do {
        let s = storage.span
        print("  span.count = \(s.count)")
        print("  span[0] = \(s[0]), span[3] = \(s[3])")
    }

    print()
    print("FINDING: span property WORKS for class via _overrideLifetime")
    print("FINDING: mutableSpan property NOT POSSIBLE for class (no mutating getter)")
    print()
}

// ============================================================================
// MARK: - Variant 2: Inline Storage with @lifetime + _overrideLifetime
// Hypothesis: Struct can have both span and mutableSpan properties
// Result: [PENDING]
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// ============================================================================

@_rawLayout(likeArrayOf: Element, count: capacity)
struct _InlineRaw<Element: ~Copyable, let capacity: Int>: ~Copyable {
    init() {}
}
extension _InlineRaw: @unchecked Sendable where Element: Sendable {}

struct InlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: _InlineRaw<Element, capacity>
    var _count: Int

    init() {
        _storage = _InlineRaw()
        _count = 0
    }
}
extension InlineStorage: @unchecked Sendable where Element: Sendable {}

extension InlineStorage where Element: ~Copyable {
    @unsafe
    @_lifetime(borrow self)
    func pointer(at index: Int) -> UnsafePointer<Element> {
        unsafe withUnsafePointer(to: _storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            return unsafe raw.advanced(by: index * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    @unsafe
    @_lifetime(&self)
    mutating func mutablePointer(at index: Int) -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.advanced(by: index * MemoryLayout<Element>.stride)
                .assumingMemoryBound(to: Element.self)
        }
    }

    mutating func initialize(to element: consuming Element, at index: Int) {
        unsafe mutablePointer(at: index).initialize(to: element)
    }

    mutating func move(at index: Int) -> Element {
        unsafe mutablePointer(at: index).move()
    }
}

extension InlineStorage where Element: Copyable {
    // Property-based span using _overrideLifetime
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let ptr = unsafe withUnsafePointer(to: _storage) { base in
                unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            }
            let span = unsafe Span(_unsafeStart: ptr, count: _count)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    // Property-based mutableSpan using _overrideLifetime
    var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let ptr = unsafe withUnsafeMutablePointer(to: &_storage) { base in
                unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            }
            let span = unsafe MutableSpan(_unsafeStart: ptr, count: _count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
    }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafePointer(to: _storage) { base throws(E) in
            let ptr = unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Element.self)
            let buffer = unsafe UnsafeBufferPointer(start: ptr, count: _count)
            return try unsafe body(buffer)
        }
    }

    mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe withUnsafeMutablePointer(to: &_storage) { base throws(E) in
            let ptr = unsafe UnsafeMutableRawPointer(base).assumingMemoryBound(to: Element.self)
            let buffer = unsafe UnsafeMutableBufferPointer(start: ptr, count: _count)
            return try unsafe body(buffer)
        }
    }
}

func testInlineStorage() {
    print("=== Variant 2: InlineStorage with _overrideLifetime ===")
    print()

    var storage = InlineStorage<Int, 8>()
    for i in 0..<4 {
        storage.initialize(to: (i + 1) * 10, at: i)
    }
    storage._count = 4

    // Test property-based span access (scoped to avoid lifetime overlap)
    print("span property test:")
    do {
        let s = storage.span
        print("  span.count = \(s.count)")
        print("  span[0] = \(s[0]), span[3] = \(s[3])")
    }

    // Test property-based mutableSpan access
    print("mutableSpan property test:")
    do {
        var ms = storage.mutableSpan
        ms[1] = 999
    }
    do {
        let s = storage.span
        print("  after mutableSpan[1] = 999: span[1] = \(s[1])")
    }

    // Clean up
    for i in 0..<4 {
        _ = storage.move(at: i)
    }

    print()
    print("FINDING: span property WORKS for struct via _overrideLifetime")
    print("FINDING: mutableSpan property WORKS for struct via _overrideLifetime")
    print()
}

// ============================================================================
// MARK: - Variant 3: Protocol Conformance Test
// ============================================================================

// Conformance for InlineStorage (struct - has both properties)
extension InlineStorage: Memory.Contiguous.`Protocol` where Element: Copyable {}

func testProtocolConformance() {
    print("=== Variant 3: Protocol Conformance ===")
    print()

    func useContiguous<C: Memory.Contiguous.`Protocol` & ~Copyable>(_ storage: borrowing C)
    where C.Element == Int {
        print("  Protocol access - span.count = \(storage.span.count)")
    }

    var inline = InlineStorage<Int, 4>()
    inline.initialize(to: 10, at: 0)
    inline.initialize(to: 20, at: 1)
    inline._count = 2

    print("InlineStorage protocol conformance:")
    useContiguous(inline)

    // Clean up
    _ = inline.move(at: 0)
    _ = inline.move(at: 1)

    print()
    print("FINDING: InlineStorage CAN conform to Memory.Contiguous.Protocol")
    print()
}

// ============================================================================
// MARK: - Summary
// ============================================================================

func printSummary() {
    print("=== SUMMARY ===")
    print()
    print("Swift 6.2 @lifetime + _overrideLifetime enables property-based Span:")
    print()
    print("STRUCT TYPES (Storage.Inline):")
    print("  ✅ var span: Span<Element> { @_lifetime(borrow self) borrowing get }")
    print("  ✅ var mutableSpan: MutableSpan<Element> { @_lifetime(&self) mutating get }")
    print("  ✅ Can conform to Memory.Contiguous.Protocol")
    print()
    print("CLASS TYPES (Storage.Heap):")
    print("  ✅ var span: Span<Element> { @_lifetime(borrow self) borrowing get }")
    print("  ❌ var mutableSpan - classes cannot have mutating getters")
    print("  ❌ Cannot fully conform to Memory.Contiguous.Protocol")
    print()
    print("PATTERN:")
    print("  1. Get pointer via closure (escapes as raw value)")
    print("  2. Create Span from pointer")
    print("  3. Use _overrideLifetime(span, borrowing: self) to establish dependency")
    print()
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testHeapStorage()
testInlineStorage()
testProtocolConformance()
printSummary()
