// MARK: - Optional<T> as Inline MaybeUninit for Span Backing Storage
// Purpose: Verify that Optional<T>'s ABI-guaranteed payload-at-offset-0
//          makes it safe to use as inline deferred-initialization storage
//          for generating iterators that need to return Span<T>.
//
// The hypothesis: `var _element: T? = nil` stored inline in a ~Copyable
// iterator struct can back a Span<T> via:
//   withUnsafeMutablePointer(to: &_element) → raw pointer → assumingMemoryBound(to: T.self)
//
// This eliminates the heap-allocated single-element buffer pattern
// (UnsafeMutablePointer<T>.allocate(capacity: 1)) used by 8 generating
// iterators across the ecosystem.
//
// Toolchain: Apple Swift 6.2 (swiftlang-6.2.x)
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// Platform: macOS 26.x (arm64)
//
// Date: 2026-03-04

// ============================================================================
// MARK: - V1: Layout Verification
// Verify that Optional<T> payload is at offset 0 for various T types.
// ============================================================================

func verifyLayout<T>(_ type: T.Type, example: T, label: String) {
    var opt: T? = example
    let optSize = MemoryLayout<Optional<T>>.size
    let optStride = MemoryLayout<Optional<T>>.stride
    let tSize = MemoryLayout<T>.size
    let tStride = MemoryLayout<T>.stride

    let actual = opt!
    let payloadMatchesOffset0 = unsafe withUnsafeMutablePointer(to: &opt) { optPtr in
        let rawOpt = unsafe UnsafeRawPointer(optPtr)
        let valueAtOffset0 = unsafe rawOpt.load(as: T.self)
        return unsafe withUnsafeBytes(of: valueAtOffset0) { b0 in
            unsafe withUnsafeBytes(of: actual) { bActual in
                b0.count == bActual.count && {
                    for i in 0..<b0.count {
                        if unsafe (b0[i] != bActual[i]) { return false }
                    }
                    return true
                }()
            }
        }
    }

    let status = payloadMatchesOffset0 ? "CONFIRMED" : "FAILED"
    print("V1  [\(label)] \(status) — Optional<\(T.self)> size=\(optSize)/\(optStride), T size=\(tSize)/\(tStride)")
}

func testV1() {
    print("=== V1: Layout Verification ===\n")
    verifyLayout(Int.self, example: 42, label: "Int")
    verifyLayout(Double.self, example: 3.14, label: "Double")
    verifyLayout(Bool.self, example: true, label: "Bool")
    verifyLayout(String.self, example: "hello", label: "String")
    verifyLayout((Int, Int).self, example: (10, 20), label: "(Int,Int)")
    verifyLayout(UInt8.self, example: 0xFF, label: "UInt8")

    // Class type — Optional uses nil pointer for .none
    final class MyClass: Sendable { let value: Int; init(_ v: Int) { value = v } }
    var opt: MyClass? = MyClass(99)
    let classOk = unsafe withUnsafeMutablePointer(to: &opt) { p in
        let raw = unsafe UnsafeRawPointer(p)
        let loaded = unsafe raw.load(as: MyClass.self)
        return loaded.value == 99
    }
    print("V1  [class] \(classOk ? "CONFIRMED" : "FAILED") — Optional<MyClass> payload at offset 0")
}

// ============================================================================
// MARK: - V2: Span Creation from Optional<T>
// Create a valid 1-element Span<T> from &optional via pointer reinterpretation.
// ============================================================================

struct V2_OptionalSpan<T: Sendable>: ~Copyable {
    var _element: T? = nil

    @_lifetime(&self)
    mutating func store(_ value: T) -> Span<T> {
        _element = value
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<T>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: T.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(&self)
    mutating func emptySpan() -> Span<T> {
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<T>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: T.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 0)
        return unsafe _overrideLifetime(s, mutating: &self)
    }
}

func testV2() {
    print("\n=== V2: Span Creation from Optional<T> ===\n")

    // Int
    do {
        var v = V2_OptionalSpan<Int>()
        do {
            let empty = v.emptySpan()
            assert(empty.isEmpty, "V2 FAILED: empty span not empty")
        }
        let span = v.store(42)
        assert(span.count == 1 && span[0] == 42, "V2 FAILED: Int")
        print("V2  [Int] CONFIRMED — span[0] = \(span[0])")
    }

    // String
    do {
        var v = V2_OptionalSpan<String>()
        let span = v.store("hello world")
        assert(span.count == 1 && span[0] == "hello world", "V2 FAILED: String")
        print("V2  [String] CONFIRMED — span[0] = \(span[0])")
    }

    // Tuple
    do {
        var v = V2_OptionalSpan<(Int, String)>()
        let span = v.store((7, "seven"))
        assert(span.count == 1 && span[0].0 == 7 && span[0].1 == "seven", "V2 FAILED: Tuple")
        print("V2  [Tuple] CONFIRMED — span[0] = \(span[0])")
    }

    // Overwrite: store multiple values, each overwriting the previous
    do {
        var v = V2_OptionalSpan<Int>()
        for i in 1...5 {
            let span = v.store(i * 10)
            assert(span[0] == i * 10, "V2 FAILED: overwrite \(i)")
        }
        print("V2  [Overwrite] CONFIRMED — 5 successive stores all correct")
    }
}

// ============================================================================
// MARK: - V3: Full Generating Iterator with Optional<T>
// A finite generating iterator that uses Optional<Element> inline storage.
// This is the pattern that replaces UnsafeMutablePointer.allocate(capacity:1).
// ============================================================================

struct V3_MappingIterator<Element: Sendable>: ~Copyable {
    var _source: Array<Int>.Iterator
    let _transform: @Sendable (Int) -> Element
    var _element: Element? = nil

    init(source: [Int], transform: @escaping @Sendable (Int) -> Element) {
        self._source = source.makeIterator()
        self._transform = transform
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Element> {
        guard maximumCount > 0 else {
            return emptySpan()
        }
        guard let sourceValue = _source.next() else {
            return emptySpan()
        }
        _element = _transform(sourceValue)
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Element>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(&self)
    private mutating func emptySpan() -> Span<Element> {
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Element>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 0)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(self: immortal)
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

func testV3() {
    print("\n=== V3: Full Generating Iterator ===\n")

    // Map: Int -> String
    do {
        var iter = V3_MappingIterator(source: [1, 2, 3, 4, 5]) { "\($0)" }
        var results: [String] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results == ["1", "2", "3", "4", "5"], "V3 FAILED: \(results)")
        print("V3  [Map Int→String] CONFIRMED — \(results)")
    }

    // Map: Int -> (Int, Int) tuple
    do {
        var iter = V3_MappingIterator(source: [1, 2, 3]) { ($0, $0 * $0) }
        var results: [(Int, Int)] = []
        while let elem = iter.next() {
            results.append(elem)
        }
        assert(results.count == 3 && results[2].1 == 9, "V3 FAILED: tuple")
        print("V3  [Map Int→(Int,Int)] CONFIRMED — \(results)")
    }

    // Empty source
    do {
        var iter = V3_MappingIterator<Int>(source: []) { $0 }
        let first = iter.next()
        assert(first == nil, "V3 FAILED: empty should be nil")
        print("V3  [Empty source] CONFIRMED — next() returns nil")
    }

    // Single element
    do {
        var iter = V3_MappingIterator(source: [42]) { $0 * 2 }
        let first = iter.next()
        let second = iter.next()
        assert(first == 84 && second == nil, "V3 FAILED: single")
        print("V3  [Single element] CONFIRMED — \(first!), then nil")
    }
}

// ============================================================================
// MARK: - V4: Infinite Iterator with Optional<T>
// Verify the pattern works for infinite generating iterators too.
// ============================================================================

struct V4_InfiniteMapIterator<Source: IteratorProtocol, Element: Sendable>: ~Copyable
where Source: Copyable, Source.Element: Sendable {
    var _source: Source
    let _transform: @Sendable (Source.Element) -> Element
    var _element: Element? = nil

    init(source: Source, transform: @escaping @Sendable (Source.Element) -> Element) {
        self._source = source
        self._transform = transform
    }

    @_lifetime(&self)
    mutating func nextSpan(maximumCount: Int) -> Span<Element> {
        guard maximumCount > 0 else {
            return emptySpan()
        }
        guard let sourceValue = _source.next() else {
            return emptySpan()
        }
        _element = _transform(sourceValue)
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Element>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 1)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(&self)
    private mutating func emptySpan() -> Span<Element> {
        let ptr = unsafe withUnsafeMutablePointer(to: &_element) { p in
            unsafe UnsafePointer<Element>(
                unsafe UnsafeRawPointer(p).assumingMemoryBound(to: Element.self)
            )
        }
        let s = unsafe Span(_unsafeStart: ptr, count: 0)
        return unsafe _overrideLifetime(s, mutating: &self)
    }

    @_lifetime(self: immortal)
    mutating func next() -> Element? {
        let span = nextSpan(maximumCount: 1)
        return span.isEmpty ? nil : span[0]
    }
}

/// Infinite counter that never returns nil
struct InfiniteCounter: IteratorProtocol, Sendable {
    var current: Int = 0
    mutating func next() -> Int? {
        defer { current += 1 }
        return current
    }
}

func testV4() {
    print("\n=== V4: Infinite Iterator ===\n")

    var iter = V4_InfiniteMapIterator(
        source: InfiniteCounter(),
        transform: { $0 * $0 }
    )

    var results: [Int] = []
    for _ in 0..<10 {
        if let v = iter.next() { results.append(v) }
    }
    let expected = [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
    assert(results == expected, "V4 FAILED: \(results)")
    print("V4  [Infinite squares] CONFIRMED — first 10: \(results)")
}

// ============================================================================
// MARK: - V5: Size Comparison
// Compare struct sizes: heap buffer vs Optional inline vs bare stored property.
// ============================================================================

@safe
struct HeapBufferStyle: ~Copyable {
    let _mutableBuffer: UnsafeMutablePointer<Int>
    var _bufferPtr: UnsafePointer<Int>
    var _bufferInitialized: Bool
    var state: Int

    init() {
        let buf = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        unsafe _mutableBuffer = buf
        unsafe _bufferPtr = UnsafePointer(buf)
        _bufferInitialized = false
        state = 0
    }

    deinit {
        if _bufferInitialized {
            unsafe _mutableBuffer.deinitialize(count: 1)
        }
        unsafe _mutableBuffer.deallocate()
    }
}

struct OptionalInlineStyle: ~Copyable {
    var _element: Int? = nil
    var state: Int = 0
}

struct BarePropertyStyle: ~Copyable {
    var _element: Int = 0
    var state: Int = 0
}

func testV5() {
    print("\n=== V5: Size Comparison ===\n")

    let heapSize = MemoryLayout<HeapBufferStyle>.size
    let heapStride = MemoryLayout<HeapBufferStyle>.stride
    let optSize = MemoryLayout<OptionalInlineStyle>.size
    let optStride = MemoryLayout<OptionalInlineStyle>.stride
    let bareSize = MemoryLayout<BarePropertyStyle>.size
    let bareStride = MemoryLayout<BarePropertyStyle>.stride

    print("V5  HeapBufferStyle:     size=\(heapSize), stride=\(heapStride)  (+ 8 bytes heap)")
    print("V5  OptionalInlineStyle: size=\(optSize), stride=\(optStride)  (0 heap)")
    print("V5  BarePropertyStyle:   size=\(bareSize), stride=\(bareStride)  (0 heap)")
    print("")
    print("V5  Optional overhead vs bare: \(optSize - bareSize) bytes (\(optStride - bareStride) stride)")
    print("V5  Heap buffer overhead vs Optional: \(heapSize - optSize) bytes in struct + 8 bytes on heap")
}

// ============================================================================
// MARK: - V6: Empty Span Safety
// Verify that emptySpan() from uninitialized Optional is safe (count: 0).
// ============================================================================

func testV6() {
    print("\n=== V6: Empty Span from Uninitialized Optional ===\n")

    var v = V2_OptionalSpan<Int>()
    // _element is nil — we're creating a Span with count: 0
    // The pointer is valid (points to the Optional's storage), count is 0,
    // so no memory is actually read.
    do {
        let empty = v.emptySpan()
        assert(empty.isEmpty, "V6 FAILED: should be empty")
        assert(empty.count == 0, "V6 FAILED: count should be 0")
        print("V6  [Uninitialized empty span] CONFIRMED — count=\(empty.count), isEmpty=\(empty.isEmpty)")
    }

    // Now store and read
    let span = v.store(99)
    assert(span[0] == 99, "V6 FAILED: after store")
    print("V6  [Store after empty] CONFIRMED — span[0]=\(span[0])")
}

// ============================================================================
// MARK: - Run All Tests
// ============================================================================

print("=== Optional<T> as Inline MaybeUninit for Span Backing Storage ===\n")

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()

print("\n=== Conclusion ===")
print("Optional<T> payload IS at byte offset 0 (ABI guarantee for single-payload enums).")
print("withUnsafeMutablePointer(to: &optional) + assumingMemoryBound(to: T.self) gives valid Span.")
print("Works for: Int, Double, Bool, String, tuple, class types.")
print("Works for: empty sources, single elements, infinite sequences, overwriting.")
print("Zero heap allocation. No deinit. No @safe.")
print("Optional<T> IS the inline MaybeUninit<T> Swift already has.")
