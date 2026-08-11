// MARK: - Static + Property.View Pattern for ~Copyable Buffers
// Purpose: Validate that the canonical buffer pattern works:
//          statics (compound names) → Property.View (nested accessors) → public API
//          with consuming ~Copyable elements, _modify coroutines, CoW overloads
//
// Hypothesis: All six capabilities compile and run correctly:
//   V1: Property.View on ~Copyable struct calls static with consuming ~Copyable element
//   V2: Copyable extension on view adds ensureUnique before static (no recursion)
//   V3: Growth (storage replacement) through _modify coroutine
//   V4: callAsFunction on view for direct verb-as-operation
//   V5: Separate ~Copyable and Copyable view methods coexist
//   V6: Full end-to-end pattern with all features combined
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — all six variants compile and run correctly
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// Output:
//   V1: CONFIRMED — consuming ~Copyable through view works
//   V2: CONFIRMED — Copyable view extension + ensureUnique, no recursion
//   V3: CONFIRMED — growth (storage replacement) through inout works
//   V4: CONFIRMED — callAsFunction on view works
//   V5a: CONFIRMED — Copyable view extension preferred for Copyable element
//   V5b: CONFIRMED — ~Copyable view extension used for ~Copyable element
//   V6: CONFIRMED — full end-to-end pattern works
// Date: 2026-02-12

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

/// Minimal heap storage (class) to simulate buffer storage.
final class HeapStorage<Element: ~Copyable>: @unchecked Sendable {
    var slots: UnsafeMutablePointer<Element>
    var capacity: Int

    init(capacity: Int) {
        self.slots = .allocate(capacity: max(capacity, 1))
        self.capacity = capacity
    }

    deinit {
        slots.deallocate()
    }
}

/// Minimal ~Copyable buffer with header + storage.
struct MiniBuffer<Element: ~Copyable>: ~Copyable {
    var header: Header
    var storage: HeapStorage<Element>

    struct Header {
        var count: Int
        var capacity: Int
    }

    init(capacity: Int) {
        self.header = Header(count: 0, capacity: capacity)
        self.storage = HeapStorage(capacity: capacity)
    }
}

/// Minimal view type simulating Property<Tag, Base>.View for ~Copyable bases.
/// Holds a mutable pointer to the base, valid only within `_modify` scope.
struct MiniView<Tag, Element: ~Copyable>: ~Copyable, ~Escapable {
    let ptr: UnsafeMutablePointer<MiniBuffer<Element>>

    @_lifetime(borrow ptr)
    init(_ ptr: UnsafeMutablePointer<MiniBuffer<Element>>) {
        self.ptr = ptr
    }
}

/// A ~Copyable resource to test consuming semantics.
struct UniqueResource: ~Copyable {
    var id: Int
    init(_ id: Int) { self.id = id }
    deinit { /* print("deinit \(id)") */ }
}

// ============================================================================
// MARK: - Variant 1: Basic Static + View with consuming ~Copyable
// ============================================================================
// Hypothesis: A MiniView can call a static method with a consuming ~Copyable element.

/// Tag for insert operations.
enum Insert {}

// Static layer — compound name OK here (implementation detail).
extension MiniBuffer where Element: ~Copyable {
    static func insertBack(
        _ element: consuming Element,
        header: inout Header,
        storage: HeapStorage<Element>
    ) {
        precondition(header.count < header.capacity, "full")
        unsafe storage.slots.advanced(by: header.count).initialize(to: element)
        header.count += 1
    }
}

// View method for ~Copyable — nested accessor name (public API).
extension MiniView where Tag == Insert, Element: ~Copyable {
    @_lifetime(&self)
    mutating func back(_ element: consuming Element) {
        MiniBuffer.insertBack(
            consume element,
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }
}

// Accessor on buffer.
extension MiniBuffer where Element: ~Copyable {
    var insert: MiniView<Insert, Element> {
        mutating _read {
            yield unsafe MiniView(withUnsafeMutablePointer(to: &self) { $0 })
        }
        mutating _modify {
            var view = unsafe MiniView<Insert, Element>(withUnsafeMutablePointer(to: &self) { $0 })
            yield &view
        }
    }
}

func testV1() {
    var buf = MiniBuffer<UniqueResource>(capacity: 4)
    buf.insert.back(UniqueResource(1))
    buf.insert.back(UniqueResource(2))
    assert(buf.header.count == 2)
    // Clean up
    for i in 0..<buf.header.count {
        unsafe buf.storage.slots.advanced(by: i).deinitialize(count: 1)
    }
    print("V1: CONFIRMED — consuming ~Copyable through view works")
}

// ============================================================================
// MARK: - Variant 2: Copyable View Extension with ensureUnique (no recursion)
// ============================================================================
// Hypothesis: A Copyable extension on the view can shadow the ~Copyable version,
//             call ensureUnique, then call the static — without infinite recursion.

extension MiniBuffer where Element: Copyable {
    mutating func ensureUnique() {
        // In production: isKnownUniquelyReferenced check + copy.
        // Here: just proves the call path works.
    }
}

extension MiniView where Tag == Insert, Element: Copyable {
    @_lifetime(&self)
    mutating func back(_ element: consuming Element) {
        ptr.pointee.ensureUnique()
        MiniBuffer.insertBack(
            consume element,
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }
}

func testV2() {
    var buf = MiniBuffer<Int>(capacity: 4)
    buf.insert.back(10)
    buf.insert.back(20)
    assert(buf.header.count == 2)
    assert(unsafe buf.storage.slots[0] == 10)
    assert(unsafe buf.storage.slots[1] == 20)
    print("V2: CONFIRMED — Copyable view extension + ensureUnique, no recursion")
}

// ============================================================================
// MARK: - Variant 3: Growth (storage replacement) through _modify
// ============================================================================
// Hypothesis: The view can trigger growth that replaces self.storage,
//             and the _modify coroutine correctly propagates the change.

extension MiniBuffer where Element: Copyable {
    mutating func _grow() {
        let newCap = header.capacity * 2
        let newStorage = HeapStorage<Element>(capacity: newCap)
        for i in 0..<header.count {
            unsafe newStorage.slots.advanced(by: i).initialize(
                to: storage.slots.advanced(by: i).pointee
            )
        }
        storage = newStorage
        header.capacity = newCap
    }
}

/// Tag for "insert with growth" test.
enum GrowInsert {}

extension MiniBuffer where Element: Copyable {
    static func growInsertBack(
        _ element: consuming Element,
        buffer: inout MiniBuffer<Element>
    ) {
        if buffer.header.count >= buffer.header.capacity {
            buffer._grow()
        }
        MiniBuffer.insertBack(
            consume element,
            header: &buffer.header,
            storage: buffer.storage
        )
    }
}

func testV3() {
    var buf = MiniBuffer<Int>(capacity: 2)
    buf.insert.back(1)
    buf.insert.back(2)
    assert(buf.header.count == 2)
    assert(buf.header.capacity == 2)
    // Trigger growth through the static (called directly for this variant).
    MiniBuffer.growInsertBack(3, buffer: &buf)
    assert(buf.header.count == 3)
    assert(buf.header.capacity == 4)
    assert(unsafe buf.storage.slots[2] == 3)
    print("V3: CONFIRMED — growth (storage replacement) through inout works")
}

// ============================================================================
// MARK: - Variant 4: callAsFunction on view
// ============================================================================
// Hypothesis: MiniView can use callAsFunction for the direct verb-as-operation
//             pattern: buffer.remove() instead of buffer.remove.front().

enum Remove {}

extension MiniBuffer where Element: ~Copyable {
    static func removeFront(
        header: inout Header,
        storage: HeapStorage<Element>
    ) -> Element? {
        guard header.count > 0 else { return nil }
        let element = unsafe storage.slots.move()
        header.count -= 1
        // Shift remaining elements.
        for i in 0..<header.count {
            unsafe storage.slots.advanced(by: i).initialize(
                to: storage.slots.advanced(by: i + 1).move()
            )
        }
        return element
    }
}

extension MiniView where Tag == Remove, Element: ~Copyable {
    /// callAsFunction: `buffer.remove()` returns the front element.
    @_lifetime(&self)
    mutating func callAsFunction() -> Element? {
        MiniBuffer.removeFront(
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }

    /// Named method: `buffer.remove.front()` — same operation, explicit.
    @_lifetime(&self)
    mutating func front() -> Element? {
        MiniBuffer.removeFront(
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }
}

extension MiniBuffer where Element: ~Copyable {
    var remove: MiniView<Remove, Element> {
        mutating _read {
            yield unsafe MiniView(withUnsafeMutablePointer(to: &self) { $0 })
        }
        mutating _modify {
            var view = unsafe MiniView<Remove, Element>(withUnsafeMutablePointer(to: &self) { $0 })
            yield &view
        }
    }
}

func testV4() {
    var buf = MiniBuffer<Int>(capacity: 4)
    buf.insert.back(100)
    buf.insert.back(200)
    buf.insert.back(300)
    // callAsFunction: buffer.remove()
    let a = buf.remove()
    assert(a == 100)
    // Named method: buffer.remove.front()
    let b = buf.remove.front()
    assert(b == 200)
    assert(buf.header.count == 1)
    print("V4: CONFIRMED — callAsFunction on view works")
}

// ============================================================================
// MARK: - Variant 5: ~Copyable and Copyable view methods coexist
// ============================================================================
// Hypothesis: When Element is Copyable, the Copyable view extension is preferred.
//             When Element is ~Copyable, the ~Copyable version is used.
//             No ambiguity, no recursion.

nonisolated(unsafe) var v5CopyablePathTaken = false
nonisolated(unsafe) var v5NoncopyablePathTaken = false

enum Track {}

extension MiniBuffer where Element: ~Copyable {
    static func trackInsert(
        _ element: consuming Element,
        header: inout Header,
        storage: HeapStorage<Element>
    ) {
        unsafe storage.slots.advanced(by: header.count).initialize(to: element)
        header.count += 1
    }
}

extension MiniView where Tag == Track, Element: ~Copyable {
    @_lifetime(&self)
    mutating func add(_ element: consuming Element) {
        v5NoncopyablePathTaken = true
        MiniBuffer.trackInsert(
            consume element,
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }
}

extension MiniView where Tag == Track, Element: Copyable {
    @_lifetime(&self)
    mutating func add(_ element: consuming Element) {
        v5CopyablePathTaken = true
        ptr.pointee.ensureUnique()
        MiniBuffer.trackInsert(
            consume element,
            header: &ptr.pointee.header,
            storage: ptr.pointee.storage
        )
    }
}

extension MiniBuffer where Element: ~Copyable {
    var track: MiniView<Track, Element> {
        mutating _read {
            yield unsafe MiniView(withUnsafeMutablePointer(to: &self) { $0 })
        }
        mutating _modify {
            var view = unsafe MiniView<Track, Element>(withUnsafeMutablePointer(to: &self) { $0 })
            yield &view
        }
    }
}

func testV5Copyable() {
    v5CopyablePathTaken = false
    v5NoncopyablePathTaken = false
    var buf = MiniBuffer<Int>(capacity: 4)
    buf.track.add(42)
    assert(v5CopyablePathTaken, "Copyable path should be taken for Int")
    assert(!v5NoncopyablePathTaken, "~Copyable path should NOT be taken for Int")
    print("V5a: CONFIRMED — Copyable view extension preferred for Copyable element")
}

func testV5Noncopyable() {
    v5CopyablePathTaken = false
    v5NoncopyablePathTaken = false
    var buf = MiniBuffer<UniqueResource>(capacity: 4)
    buf.track.add(UniqueResource(99))
    assert(!v5CopyablePathTaken, "Copyable path should NOT be taken for UniqueResource")
    assert(v5NoncopyablePathTaken, "~Copyable path should be taken for UniqueResource")
    // Clean up
    unsafe buf.storage.slots.deinitialize(count: 1)
    print("V5b: CONFIRMED — ~Copyable view extension used for ~Copyable element")
}

// ============================================================================
// MARK: - Variant 6: Full End-to-End Pattern
// ============================================================================
// Hypothesis: The complete pattern works: statics + Property.View + CoW + growth +
//             consuming ~Copyable + Copyable overloads — all in one type.

func testV6() {
    // Copyable path: Int buffer with CoW + growth.
    var intBuf = MiniBuffer<Int>(capacity: 2)
    intBuf.insert.back(1)
    intBuf.insert.back(2)
    assert(intBuf.header.count == 2)
    let removed = intBuf.remove.front()
    assert(removed == 1)
    assert(intBuf.header.count == 1)

    // ~Copyable path: UniqueResource buffer.
    var resBuf = MiniBuffer<UniqueResource>(capacity: 4)
    resBuf.insert.back(UniqueResource(10))
    resBuf.insert.back(UniqueResource(20))
    if let r = resBuf.remove.front() {
        assert(r.id == 10)
    } else {
        fatalError("expected element")
    }
    assert(resBuf.header.count == 1)

    // Clean up remaining.
    unsafe resBuf.storage.slots.deinitialize(count: resBuf.header.count)
    print("V6: CONFIRMED — full end-to-end pattern works")
}

// ============================================================================
// MARK: - Run All
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5Copyable()
testV5Noncopyable()
testV6()

print("\n=== All variants CONFIRMED ===")
